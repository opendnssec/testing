#!/usr/bin/env perl
#
# Author Jerry Lundström <jerry@opendnssec.org>
# Copyright (c) 2013 .SE (The Internet Infrastructure Foundation).
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

use strict;
use SOAP::Lite ();
use YAML ();

my $HOST = "https://crowd.opendnssec.org/crowd/services/SecurityServer";
my $NS = "urn:SecurityServer";
my $XMLNS = 'http://authentication.integration.crowd.atlassian.com';
my $CONFIG = {};
my $CONFIG_FILE = '/etc/crowd-sshd.yaml';

sub make_soap_call {
    my ($method, @params) = @_;

    my $search = SOAP::Lite
        ->readable(1)
        ->xmlschema('http://www.w3.org/2001/XMLSchema')
        ->on_action(sub { return '""'; })
        ->proxy($HOST)
        ->uri($NS)
        ->default_ns($XMLNS);

    my $app_method = SOAP::Data->name($method)->uri($NS);

    return $search->call($app_method => @params);
}

unless (defined $ARGV[0]) {
    print STDERR 'Missing argument: user';
    exit 1;
}

unless (-r $CONFIG_FILE) {
    if (defined $ENV{CROWD_SSHD_CONFIG} and -r $ENV{CROWD_SSHD_CONFIG}) {
        $CONFIG_FILE = $ENV{CROWD_SSHD_CONFIG};
    }
    else {
        print STDERR 'No config file found', "\n";
        exit 1;
    }
}

eval {
    $CONFIG = YAML::LoadFile($CONFIG_FILE);
};
if ($@ or !defined $CONFIG or ref($CONFIG) ne 'HASH') {
    print STDERR 'Unable to load config file: ', $@, "\n";
    exit 1;
}

unless (defined $CONFIG->{user} and defined $CONFIG->{password}) {
    print STDERR 'Config error, missing user and/or password!', "\n";
    exit 1;
}

my $som = make_soap_call('authenticateApplication',
    SOAP::Data->name('in0' => \SOAP::Data->value(
        SOAP::Data->name('credential' => \SOAP::Data->value(
            SOAP::Data->name('credential' => $CONFIG->{password}))
        )->attr({xmlns => $XMLNS}),
        SOAP::Data->name('name' => $CONFIG->{user})->attr({xmlns => $XMLNS}),
        SOAP::Data->name('validationFactors' => undef)->attr({xmlns => $XMLNS})
    )));

if ($som->fault) {
    print STDERR 'SOAP Fault ', $som->faultcode, ': ', $som->faultstring, "\n";
    exit 1;
}

my $token = $som->valueof('//token');

unless ($token) {
    print STDERR 'Authentication failed, no token!', "\n";
    exit 1;
}

$som = make_soap_call('findPrincipalWithAttributesByName',
    SOAP::Data->name('in0' => \SOAP::Data->value(
        SOAP::Data->name('name' => $CONFIG->{user})->attr({xmlns => $XMLNS}),
        SOAP::Data->name('token' => $token)->attr({xmlns => $XMLNS})
    )),
    SOAP::Data->name('in1' => $ARGV[0])
    );

if ($som->fault) {
    print STDERR 'SOAP Fault ', $som->faultcode, ': ', $som->faultstring, "\n";
    exit 1;
}

foreach ($som->valueof('//SOAPAttribute')) {
    unless (ref($_) eq 'HASH'
        and exists $_->{name} and $_->{name} eq 'authorizedKey'
        and exists $_->{values} and ref($_->{values}) eq 'HASH'
        and defined $_->{values}->{string})
    {
        next;
    }
    
    foreach my $key (ref($_->{values}->{string}) eq 'ARRAY' ? @{$_->{values}->{string}} : $_->{values}->{string}) {
        print $key,"\n";
    }
}

exit 0;
