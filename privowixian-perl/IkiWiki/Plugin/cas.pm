#!/usr/bin/perl
# JaSIG CAS support by Bruno Beaufils <bruno@boulgour.com>
package IkiWiki::Plugin::cas;

use warnings;
use strict;
use IkiWiki 3.00;

######################################################################

# TODO: if cas is alone, authentify directly without going to signin
# TODO: should we check_config to ensure cas_url and ca_file are set ?

######################################################################

sub import {
	hook(type => "getopt", id => "cas", call => \&getopt);
	hook(type => "getsetup", id => "cas", call => \&getsetup);
	hook(type => "formbuilder_setup", id => "cas", call => \&formbuilder_setup, first => 1);
	hook(type => "auth", id => "cas", call => \&auth);
}

######################################################################

sub getopt () {
	eval q{use Getopt::Long};
	error($@) if $@;
	Getopt::Long::Configure('pass_through');
	GetOptions("cas_url=s" => \$config{cas_url});
	GetOptions("ca_file=s" => \$config{ca_file});
}

######################################################################

sub getsetup () {
	plugin => {
		safe => 1,
		rebuild => 1,
	},
	cas_url => {
		type => "string",
		example => "http://sso-cas.example.com",
		description => "Main URL of CAS Single Sign On server",
		safe => 1,
		rebuild => 1,
	},
	ca_file => {
		type => "string",
		example => "/etc/ssl/certs/ca-certificates.crt",
		description => "File containing list of trusted Central Authorities certificates used by the server",
		safe => 0,
		rebuild => 1,
	},
}

######################################################################

sub formbuilder_setup (@) {
	my %params=@_;
	
	my $form=$params{form};
	my $session=$params{session};
	my $cgi=$params{cgi};
	my $buttons=$params{buttons};
	my $cas;
	
	# Give up if module is unavailable.
	eval q{use AuthCAS};
	if ($@) {
		debug("CAS: formbuilder_setup(): unable to load AuthCAS, not enabling CAS login ($@)");
		return;
	}
	
	if ($form->title eq "signin") {
		# This avoids displaying a redundant label for the CAS
		# fieldset.
		$form->fieldsets("CAS");
		
		# Add a field with the ikiwiki CGI URL (for WIND)
		$form->field(
			name => "cas_url",
			label => gettext("Log in with")." CAS",
			options => [$config{'cas_url'}],
			fieldset => "CAS"
			);

		# Force it if CAS is the only auth method
		if (scalar keys %{$IkiWiki::hooks{auth}} == 1) {
			$form->field(
				name => "cas_url",
				value => $config{'cas_url'},
				force => 1,
###				validate => sub { validate($cgi, $session, shift, $form); },
				);
###			decode_form_utf8($form);
###			$form->validate();
		}
		
		# Handle submission of CAS as validating system.
		if ($form->submitted
			&& $form->submitted eq "Login"
			&& defined $form->field("cas_url")
			&& $form->field("cas_url") eq $config{'cas_url'})
		{ 
			$form->field(
				name => "cas_url",
				validate => sub { validate($cgi, $session, shift, $form); },
				);
			# Skip all other required fields in this case.
			foreach my $field ($form->field) {
				next if $field eq "cas_url";
				$form->field(name => $field,
							 required => 0,
							 validate => '/.*/');
			}
		}
	} elsif ($form->title eq "preferences") {
		# Show the CAS ID
		$form->field(name => "CAS ID",
					 disabled => 1,
					 value => $session->param("name")."@[".$config{'cas_url'}."]", 
					 size => 50,
					 force => 1,
					 fieldset => "login");
	}

	# Force a logout if asked
	if (defined $form->submitted && $form->submitted eq 'Logout') {
		my $cas = new AuthCAS(casUrl => $config{'cas_url'},
							  CAFile => $config{'ca_file'});
		debug("CAS: formbuilder_setup(): asking to remove the Ticket Grant Cookie");
		$session->delete();
		IkiWiki::redirect($cgi, $cas->getServerLogoutURL($config{'url'}));
		exit 0;
	}
}

######################################################################

sub validate ($$$;$) {
	my $q=shift;
	my $session=shift;
	my $cas_url=shift;
	my $form=shift;
	
	$q->append(name=>'cas_url', value=>$config{'cas_url'});
	auth($q, $session);
	exit 0;
}

######################################################################

sub auth ($$) {
	my $q=shift;
	my $session=shift;
	
	# Try to authentify only if : 
	#  * module AuthCAS is available
	#  * user is not already authentified
	#  * cas_url is in the query
	eval q{use AuthCAS};
	if (! $@
		&& !defined $session->param('name')
		&& defined $q->param('cas_url')){
		
		# Create AuthCAS objects used to process identification
		my $cas = new AuthCAS(casUrl => $config{'cas_url'},
							  CAFile => $config{'ca_file'});
		
		# CAS service is postsignin
		my $service;
		$service = IkiWiki::cgiurl(do => 'postsignin',
								   cas_url => $config{'cas_url'});
		
		# Get the ticket in the query string (if coming back from CAS)
		my $ticket = $q->param('ticket');
		
		# If no ticket, ask one to CAS server and come back here
		unless (defined($ticket)) {
			my $login_url = $cas->getServerLoginURL($service);
			$login_url = $q->referer;
			debug("CAS: auth(): asking a Service Ticket for service $service");
			IkiWiki::redirect($q, $login_url);
			exit 0;
		} else {
			$service =~ s/\&ticket=$ticket//;
			my $user = $cas->validateST($service, $ticket);
			if (defined $user) {
				debug("CAS: auth(): validating a Service Ticket ($ticket) for service $service");
				$session->param(name=>$user);
				$session->param(CASservice=>$service);
				IkiWiki::cgi_savesession($session);
			} else {
				error("CAS failure: ".&AuthCAS::get_errors());
			}
		}
	}
}

######################################################################

1

# Local Variables:
# tab-width: 4
# fill-column: 70
# End:
