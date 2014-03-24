#!/usr/bin/perl

use common::sense;
use Carp;

use Scalar::Util qw(blessed);
use Pod::Usage ();
use Getopt::Long ();
use JSON::XS ();
use LWP::UserAgent ();
use HTTP::Request ();
use MIME::Base64 ();
use XML::LibXML ();

my $help = 0;
my $user;
my $token;
my $base_url = 'https://jenkins.opendnssec.org/';
my $JSON = JSON::XS->new;

Getopt::Long::GetOptions(
    'help|?' => \$help,
    'user=s' => \$user,
    'token=s' => \$token,
    'base-url:s' => \$base_url
) or Pod::Usage::pod2usage(2);
Pod::Usage::pod2usage(1) if $help;
my ($cmd, $pattern) = @ARGV;
unless ($user and $token and $cmd =~ /^(?:add|remove|search|rename|backup|restore|delete-job|create)$/o and $pattern) {
    Pod::Usage::pod2usage(1);
}

if ($base_url !~ /\/$/o) {
    $base_url .= '/';
}

if ($cmd eq 'create') {
    $pattern =~ s/\/+$//o;
    unless (-d $pattern and opendir(DIR, $pattern)) {
        die;
    }

    while((my $entry = readdir(DIR))) {
        unless (-f $pattern.'/'.$entry and $entry =~ /\.xml$/o) {
            next;
        }
        my $name = $entry;
        $name =~ s/\.xml$//o;
        
        print '+ ', $name, "\n";
        unless (open(XML, '<', $pattern.'/'.$entry)) {
            die;
        }
        my $config;
        while(<XML>) {
            $config .= $_;
        }
        close(XML);
        unless ($config) {
            die;
        }
        my $post = JenkinsRequest('createItem?name='.$name,
            headers => {
                'Content-Type' => 'text/xml'
            },
            method => 'POST',
            no_json => 1,
            body => $config);
        unless (defined $post) {
            die;
        }
    }
    close(DIR);
    exit(0);
}

my $jenkins = JenkinsRequest('');
unless (ref($jenkins) eq 'HASH' and ref($jenkins->{jobs}) eq 'ARRAY') {
    die;
}

foreach my $job (@{$jenkins->{jobs}}) {
    unless (ref($job) eq 'HASH' and exists $job->{name} and exists $job->{url}) {
        die;
    }
    
    if ($job->{name} =~ /$pattern/o) {
        print 'job ', $job->{name}, "\n";
        
        my $config = JenkinsRequest($job->{url}.'config.xml', no_json => 1);
        unless ($config) {
            die;
        }

        if ($cmd eq 'add') {
            my (undef, undef, @nodes) = @ARGV;
            my ($dom, $values, $found, $changed);
            
            foreach my $node (@nodes) {
                ($dom, $values, $found) = FindNode($dom ? $dom : $config, $node);
                unless ($values) {
                    next;
                }
                unless ($found) {
                    print '  + ', $node, "\n";
                    $values->appendTextChild('string', $node);
                    $changed = 1;
                }
            }
            
            if ($dom and $changed) {
                SaveXML($job, $dom);
            }
        }
        elsif ($cmd eq 'remove') {
            my (undef, undef, @nodes) = @ARGV;
            my ($dom, $values, $found, $changed);
            
            foreach my $node (@nodes) {
                ($dom, $values, $found) = FindNode($dom ? $dom : $config, $node);
                unless ($values) {
                    next;
                }
                if ($found) {
                    print '  - ', $found->textContent, "\n";
                    $values->removeChild($found);
                    $changed = 1;
                }
            }
            
            if ($dom and $changed) {
                SaveXML($job, $dom);
            }
        }
        elsif ($cmd eq 'search') {
            my (undef, undef, @nodes) = @ARGV;
            my ($dom, $values, $found);
            
            foreach my $node (@nodes) {
                ($dom, $values, $found) = FindNode($dom ? $dom : $config, $node);
                unless ($values) {
                    next;
                }
                if ($found) {
                    print '  ', $found->textContent, "\n";
                }
            }
        }
        elsif ($cmd eq 'rename') {
            unless ($ARGV[3]) {
                die;
            }
            my ($dom, $values, $found) = FindNode($config, $ARGV[2]);
            unless ($values) {
                next;
            }
            if ($found) {
                print '  ', $found->textContent, ' => ', $ARGV[3], "\n";
                $values->removeChild($found);
                $values->appendTextChild('string', $ARGV[3]);
                SaveXML($job, $dom);
            }
        }
        elsif ($cmd eq 'backup') {
            unless (-d $ARGV[2]) {
                die;
            }
            my $directory = $ARGV[2];
            $directory =~  s/\/+$//o;
            unless (open(XML, '>', $directory.'/'.$job->{name}.'.xml')
                and print XML $config
                and close(XML))
            {
                die;
            }
        }
        elsif ($cmd eq 'restore') {
            unless (-d $ARGV[2]) {
                die;
            }
            my $directory = $ARGV[2];
            $directory =~  s/\/+$//o;
            if (-f $directory.'/'.$job->{name}.'.xml') {
                print '  restoring', "\n";
                unless (open(XML, '<', $directory.'/'.$job->{name}.'.xml')) {
                    die;
                }
                my $config;
                while(<XML>) {
                    $config .= $_;
                }
                close(XML);
                unless ($config) {
                    die;
                }
                SaveXML($job, $config);
                print '  restored', "\n";
            }
        }
        elsif ($cmd eq 'delete-job') {
            my $post = JenkinsRequest($job->{url}.'doWipeOutWorkspace?',
                method => 'POST',
                no_json => 1);
            if ($@ == 302) {
                undef $@;
                $post = 1;
            }
            unless (defined $post) {
                die;
            }
            my $post = JenkinsRequest($job->{url}.'doDelete?',
                method => 'POST',
                no_json => 1);
            if ($@ == 302) {
                undef $@;
                $post = 1;
            }
            unless (defined $post) {
                die;
            }
        }
        else {
            die;
        }
    }
}
exit(0);

sub SaveXML {
    my ($job, $dom) = @_;
    
    my $post = JenkinsRequest($job->{url}.'config.xml',
        method => 'POST',
        no_json => 1,
        body => blessed $dom ? $dom->toString : $dom);
    unless (defined $post) {
        die;
    }
}

sub FindNode {
    my ($config, $node) = @_;
    my $dom = blessed $config ? $config : XML::LibXML->load_xml(string => $config);
    
    unless ($dom->findnodes('/matrix-project')) {
        return ($dom);
    }
    
    my ($values) = ($dom->findnodes('/matrix-project/axes/hudson.matrix.LabelAxis/values'));
    unless (defined $values) {
        my $axis = $dom->findnodes('/matrix-project/axes/hudson.matrix.LabelAxis');
        unless (defined $axis) {
            my $axes = $dom->findnodes('/matrix-project/axes');
            unless (defined $axes) {
                my $matrix = $dom->findnodes('/matrix-project');
                unless (defined $matrix) {
                    die;
                }
                $matrix->appendChild(($axes = XML::LibXML::Element->new('axes')));
            }
            $axes->appendChild(($axis = XML::LibXML::Element->new('hudson.matrix.LabelAxis')));
        }
        $axis->appendChild(($values = XML::LibXML::Element->new('values')));
    }

    my $found;
    foreach my $string ($values->findnodes('string')) {
        if ($string->textContent eq $node) {
            $found = $string;
        }
    }
    
    return ($dom, $values, $found);
}

sub JenkinsRequest {
    my $url = shift;
    my %args = ( @_ );
    my $method = delete $args{method} || 'GET';
    my $no_json = delete $args{no_json};

    $url =~ s/^$base_url//;
    unless ($url =~ /\?/o) {
        if ($url !~ /\/$/o) {
            $url .= '/';
        }
        $url .= 'api/json';
    }
    $args{headers}->{Authorization} = 'Basic '.MIME::Base64::encode($user.':'.$token, '');
    
    #print 'JenkinsRequest ', $method, ' ', $base_url, $url, "\n";
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
    $ua->agent('curl/7.32.0');
    
    my $request = HTTP::Request->new($method => $base_url.$url);
    $request->header(%{$args{headers}});
    if (exists $args{body}) {
        $request->content($args{body});
    }
    
    my $response = $ua->request($request);
    unless ($response->is_success) {
        print STDERR $response->status_line, "\n";
        $@ = $response->code;
        return;
    }
    
    if ($no_json) {
        return $response->content;
    }
    
    my $body;
    eval {
        $body = $JSON->decode($response->content);
    };
    if ($@) {
        print STDERR $@;
        return;
    }
    return $body;
}


__END__

=head1 NAME

exec - Description

=head1 SYNOPSIS

exec --user <user> --token <token> <add|remove|search> <job pattern> <node ... node>

exec --user <user> --token <token> <rename> <job pattern> <old node> <new node>

exec --user <user> --token <token> <backup|restore> <job pattern> <destination directory>

exec --user <user> --token <token> <delete-job> <job pattern>

exec --user <user> --token <token> <create> <job xml directory>

=cut
