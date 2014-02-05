#!/usr/bin/perl

use common::sense;
use Carp;

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
my $JSON = JSON::XS->new;

Getopt::Long::GetOptions(
    'help|?' => \$help,
    'user=s' => \$user,
    'token=s' => \$token
) or Pod::Usage::pod2usage(2);
Pod::Usage::pod2usage(1) if $help;
my ($cmd, $node, $pattern) = @ARGV;
unless ($user and $token and $cmd =~ /^(?:add|remove|search|rename)$/o and $node and $pattern) {
    Pod::Usage::pod2usage(1);
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

        my $dom = XML::LibXML->load_xml(string => $config);
        unless ($dom->findnodes('/matrix-project')) {
            next;
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
        
        my $changed;
        if ($cmd eq 'add') {
            unless ($found) {
                print '  + ', $node, "\n";
                $values->appendTextChild('string', $node);
                $changed = 1;
            }
        }
        elsif ($cmd eq 'remove') {
            if ($found) {
                print '  - ', $found->textContent, "\n";
                $values->removeChild($found);
                $changed = 1;
            }
        }
        elsif ($cmd eq 'search') {
            if ($found) {
                print '  ', $found->textContent, "\n";
            }
        }
        elsif ($cmd eq 'rename') {
            unless ($ARGV[3]) {
                die;
            }
            if ($found) {
                print '  ', $found->textContent, ' => ', $ARGV[3], "\n";
                $values->removeChild($found);
                $values->appendTextChild('string', $ARGV[3]);
                $changed = 1;
            }
        }
        else {
            die;
        }
        
        if ($changed) {
            my $post = JenkinsRequest($job->{url}.'config.xml',
                method => 'POST',
                no_json => 1,
                body => $dom->toString);
            unless (defined $post) {
                die;
            }
        }
    }
}
exit(0);

sub JenkinsRequest {
    my $url = shift;
    my %args = ( @_ );
    my $method = delete $args{method} || 'GET';
    my $no_json = delete $args{no_json};
    
    $url =~ s/^https:\/\/jenkins.opendnssec.org\///o;
    unless ($url =~ /\?/o) {
        $url =~ s/\/+$//o;
        $url .= '/api/json';
    }
    $args{headers}->{Authorization} = 'Basic '.MIME::Base64::encode($user.':'.$token, '');
    
    #print 'JenkinsRequest ', $method, ' https://jenkins.opendnssec.org/', $url, "\n";
    my $ua = LWP::UserAgent->new;
    $ua->agent('curl/7.32.0');
    
    my $request = HTTP::Request->new($method => 'https://jenkins.opendnssec.org/'.$url);
    $request->header(%{$args{headers}});
    if (exists $args{body}) {
        $request->content($args{body});
    }
    
    my $response = $ua->request($request);
    unless ($response->is_success) {
        print STDERR $response->status_line, "\n";
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

exec --user <user> --token <token> --base <base url> <add|remove|search|rename> <node> <job pattern> [...]

=cut
