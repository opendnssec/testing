#!/usr/bin/perl
#
# $Id$
#
# Copyright (c) 2011 .SE (The Internet Infrastructure Foundation).
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# ************************************************************
# *
# * This perl script generates TLD zone files 
# *
# ************************************************************

use strict;
use Getopt::Long;
use Pod::Usage;

######################################################################

sub main {
    my $help		= 0;
    my $zone_name;
    my $ttl		= 3600;
    my $number_domains;
    my $number_ns;
    my $percent_ds	= 0;
    my $percent_aaaa	= 0;
    my $output_path;

    GetOptions(
        'help|?'         => \$help,
        'zonename=s'     => \$zone_name,
        'ttl=i'          => \$ttl,
        'domains=i'      => \$number_domains,
        'ns=i'           => \$number_ns,
        'ds=i'           => \$percent_ds,
        'aaaa=i'         => \$percent_aaaa,
        'output=s'       => \$output_path
    ) or pod2usage(1);
    pod2usage(1) if ($help);

    unless($zone_name) {
        print "Error: You must specify the name of the zone.\n";
        pod2usage(1);
    }

    if($ttl <= 0) {
        print "Error: You must specify the TTL for the RR.\n";
        pod2usage(1);
    }
    if($number_domains <= 0) {
        print "Error: You must specify the number of domains in the zone.\n";
        pod2usage(1);
    }
    if($number_ns <= 0) {
        print "Error: You must specify the number of NS per delegation.\n";
        pod2usage(1);
    }
    if($percent_ds < 0 || $percent_aaaa < 0) {
        print "Error: The number of percent must be between 0 and 100.\n";
        pod2usage(1);
    }
    if($percent_ds > 100 || $percent_aaaa > 100) {
        print "Error: The number of percent must be between 0 and 100.\n";
        pod2usage(1);
    }
    unless($output_path) {
        print "Error: You must specify a path where the zones will be stored.\n";
        pod2usage(1);
    }

    createZone($zone_name, $ttl, $number_domains, $number_ns,
		$percent_ds, $percent_aaaa, $output_path);
}

sub createZone {
    my $zone_name          = shift;
    my $ttl                = shift;
    my $number_domains     = shift;
    my $number_ns          = shift;
    my $percent_ds         = shift;
    my $percent_aaaa       = shift;
    my $output_path        = shift;

    open my $file_handle, ">", "$output_path" or die("Error: Could not open file for output.");

    createZoneApex($file_handle, $zone_name, $ttl);

    my $counter;
    for($counter = 1; $counter <= $number_domains; $counter++) {
        my $label = sprintf("domain%i.%s", $counter, $zone_name);
        createDomain($file_handle, $label, $ttl, $number_ns, 
			$percent_ds, $percent_aaaa);
    }

    close $file_handle;
}

sub createZoneApex {
    my $file_handle = shift;
    my $zone_name = shift;
    my $ttl = shift;

    print $file_handle "$zone_name. $ttl IN SOA ns1.$zone_name. postmaster.nic.$zone_name. 1000 1200 180 1209600 $ttl\n";
    print $file_handle "$zone_name. $ttl IN NS ns1.$zone_name.\n";
    print $file_handle "$zone_name. $ttl IN NS ns2.$zone_name.\n";
    print $file_handle "$zone_name. $ttl IN NS ns3.$zone_name.\n";
    print $file_handle "$zone_name. $ttl IN NS ns4.$zone_name.\n";
    print $file_handle "$zone_name. $ttl IN NS ns5.$zone_name.\n";
    print $file_handle "ns1.$zone_name. $ttl IN A 192.0.2.1\n";
    print $file_handle "ns2.$zone_name. $ttl IN A 192.0.2.1\n";
    print $file_handle "ns3.$zone_name. $ttl IN A 192.0.2.1\n";
    print $file_handle "ns4.$zone_name. $ttl IN A 192.0.2.1\n";
    print $file_handle "ns5.$zone_name. $ttl IN A 192.0.2.1\n";

    # Also add the nic domain
    print $file_handle "nic.$zone_name. $ttl IN MX 10 mail.nic.$zone_name.\n";
    print $file_handle "mail.nic.$zone_name. $ttl IN A 192.0.2.1\n";
}

sub createDomain() {
    my $file_handle = shift;
    my $domain_name = shift;
    my $ttl = shift;
    my $number_ns = shift;
    my $percent_ds = shift;
    my $percent_aaaa = shift;

    my $counter;
    my $random_number;

    # Create NS, delegation
    for($counter = 1; $counter <= $number_ns; $counter++) {
        print $file_handle "$domain_name. $ttl IN NS ns$counter.$domain_name.\n";
        print $file_handle "ns$counter.$domain_name. $ttl IN A 192.0.2.1\n";

        # Create AAAA for NS
        $random_number = int(rand(100));
        if($random_number < $percent_aaaa) {
            print $file_handle "ns$counter.$domain_name. $ttl IN AAAA 2001:0db8:85a3:0000:0000:8a2e:0370:7334\n";
        }
    }

    # Create DS
    $random_number = int(rand(100));
    if($random_number < $percent_ds) {
        print $file_handle "$domain_name. $ttl IN DS 22922 7 1 f62411de95a5b7bcabe976c0e65034a35a9fa937\n";
    }
}

main;

__END__

=head1 NAME

zonegen - a simple script that generates TLD zones

=head1 SYNOPSIS

zonegen [options]

Options:

 --help           brief help message
 --zonename S     The name of the zone. E.g. largetld or.
 --ttl N          The TTL to use
 --domains N      Number of subdomains in the zone
 --ns N           Number of NS in a delegation
 --ds N           0-100 % chance that a delegation will get a DS RR
 --aaaa N         0-100 % chance that a delegation will get an AAAA RR
 --output S       The location where the generated zone will be stored

Example - To generate a TLD zone with one million domains.
Each deletegation gets 2 new NS with glue, where 25 percent will also have IPv6.
30 percent of the domains will have a DS RR.


  perl tldgen.pl --zonename largetld --domains 1000000 --ns 2 \
                 --ds 30 --aaaa 25 --output largetld.zone
