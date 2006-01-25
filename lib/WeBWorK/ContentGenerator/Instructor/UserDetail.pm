################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: 
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::UserDetail;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserDetail - Detailed User specific information

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(sortByName);
use WeBWorK::Debug;

use constant DATE_FIELDS => {   open_date    => " Open: ",
	                            due_date     => " Due&nbsp;: ",
	                            answer_date  => " Ans&nbsp;: "
};
use constant DATE_FIELDS_ORDER =>[qw(open_date due_date answer_date )];
sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	my $db = $r->db;
	my $authz = $r->authz;
	my $userID = $r->param("user");
	my $editForUserID = $urlpath->arg("userID");

	return CGI::div({class => "ResultsWithError"}, "You are not authorized to edit user specific information.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");

	# templates for getting field names
	my $userTemplate = $self->{userTemplate} = $db->newUser;
	my $permissionLevelTemplate = $self->{permissionLevelTemplate} = $db->newPermissionLevel;
	
	# first check to see if a save form has been submitted
	return '' unless $r->param('save_button');
	
	# As it stands we need to check each set to see if it is still assigned 
	# the forms are not currently set up to simply transmit changes
	
	#Get the list of sets and the global set records
	my @setIDs = $db->listGlobalSets;
	my @setRecords = grep { defined $_ } $db->getGlobalSets(@setIDs);
	
	my @assignedSets = ();
	foreach my $setID (@setIDs) {
		push @assignedSets, $setID if defined($r->param("set.$setID.assignment"));
	}
	debug("assignedSets", join(" ", @assignedSets));
	my %selectedSets = map { $_ => 1 } @assignedSets;
	#debug ##########################
		#print STDERR ("aSsigned sets", join(" ",@assignedSets));
        #my @params = $r->param();
        #print STDERR " parameters ", join(" ", @params);
    ###############
	#Get the user(s) whose records are to be modified
	#  for now: $editForUserID
	# check the user exists?  Is this necessary?
	my $editUserRecord = $db->getUser($editForUserID);
	die "record not found for $editForUserID.\n" unless $editUserRecord;
	
	
	#Perform the desired assignments or deletions
	my %userSets = map { $_ => 1 } $db->listUserSets($editForUserID);
			
	# go through each possible set
	debug(" parameters ", join(" ", $r->param()) );
	foreach my $setRecord (@setRecords) {
		my $setID = $setRecord->set_id;
		# does the user want it to be assigned to the selected user
		if (exists $selectedSets{$setID}) {
				$self->assignSetToUser($editForUserID, $setRecord);
				#override dates
				

				my $userSetRecord = $db->getUserSet($editForUserID, $setID);
				# get the dates
				


				#do checks to see if new dates meet criteria
				my $rh_dates = $self->checkDates($setRecord,$setID);
				unless  ( $rh_dates->{error} ) { #returns 1 if error
					# if no error update database
					foreach my $field (keys %{DATE_FIELDS()}) {
						if (defined $r->param("set.$setID.$field.override")) {
							$userSetRecord->$field($rh_dates->{$field});		   
						} else {
							$userSetRecord->$field(undef); #stop override
						}
					}
					$db->putUserSet($userSetRecord);
				
				}

		} else {
			# user asked to NOT have the set assigned to the selected user
			# debug("deleteUserSet($editForUserID, $setID)");
			$db->deleteUserSet($editForUserID, $setID);
			# debug("done deleteUserSet($editForUserID, $setID)");
		}
	}
	
	return '';
	
	
	
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $courseID = $urlpath->arg("courseID");
	my $editForUserID = $urlpath->arg("userID");
	my $userID = $r->param("user");
	
	my @editForSets = $r->param("editForSets");
	
	return CGI::div({class => "ResultsWithError"}, "You are not authorized to edit user specific information.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");
	
	my $UserRecord = $db->getUser($editForUserID);
	my $PermissionRecord = $db->getPermissionLevel($editForUserID);
	my @UserSetIDs = $db->listUserSets($editForUserID);
	
	my $userName = $UserRecord->first_name . " " . $UserRecord->last_name;

	# templates for getting field names
	my $userTemplate = $self->{userTemplate};
	my $permissionLevelTemplate = $self->{permissionLevelTemplate};
	
	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map { $_ => $_ } 
		$userTemplate->FIELDS();
	
# 	@prettyFieldNames{qw(
# 		#user_id
# 		first_name
# 		last_name
# 		email_address
# 		student_id
# 		status
# 		section
# 		recitation
# 		comment
# 		permission
# 	)} = (
# 		#"Login Name",
# 		"First Name",
# 		"Last Name",
# 		"Email",
# 		"Student ID",
# 		"Status",
# 		"Section",
# 		"Recitation",
# 		"Comment",
# 		"Permission Level",
# 	);
	
	my @dateFields         = @{DATE_FIELDS_ORDER()};
	my $rh_dateFieldLabels =  DATE_FIELDS();


	# create a link to the SetsAssignedToUser page
# 	my $editSetsPath = $urlpath->newFromModule(
# 		"WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser",
# 		courseID => $courseID,
# 		userID => $userID,
# 	);
# 	my $editSetsAssignedToUserURL = $self->systemLink($editSetsPath);
	
	# create a message about how many sets have been assigned to this user
 	my $setCount = $db->countUserSets($editForUserID);
# 	my $userCountMessage =  CGI::a({href=>$editSetsAssignedToUserURL}, $setCount . " sets.");
# 	$userCountMessage = "The user " . CGI::b($userName . " ($editForUserID)") . " has been assigned " . $userCountMessage;
	my $basicInfoPage = $urlpath->new(type =>'instructor_user_list',
					args =>{
						courseID => $courseID,
	                }
	    );
		my $basicInfoUrl = $self->systemLink($basicInfoPage,
		                                     params =>{visible_users => $editForUserID,
		                                               editMode      => 1,
		                                              }
		);

	print CGI::h4({align=>'center'},"Edit ",CGI::a({href=>$basicInfoUrl},'class list data')," for  $userName ($editForUserID) who has been assigned $setCount sets.");
	
	#print CGI::h4("User Data");
# 	print CGI::start_table({ align=>'center', border=>1,cellpadding=>5});
# 	print CGI::Tr(
# 		CGI::th(CGI::checkbox({ type => 'checkbox',
# 								name => "edit.basic.info",
# 								label => '',
#                         		checked => 0
#         }),"Edit class list data for $editForUserID"),
#         CGI::th(CGI::checkbox({ type => 'checkbox',
# 								name => "change.password",
# 								label => '',
#                         		checked => 0
#         }),"Change Password for $editForUserID"));
#         
# 	print "<tr><td rowspan=\"2\">";
# 	########################################
# 	# Basic student data
# 	########################################
# 	print CGI::start_table();
# 	foreach ($userTemplate->FIELDS()) {
# 		next if $_ eq 'user_id';   # don't print login name
# 		print CGI::Tr(
# 			CGI::td([
# 		        	$prettyFieldNames{$_}, 
# 				CGI::input({ -value => $UserRecord->$_, -size => 25 })
# 			])
# 		);
# 	}
# 	foreach ($permissionLevelTemplate->FIELDS()) {
# 		print CGI::Tr(
# 			CGI::td([
# 		        	$prettyFieldNames{$_}, 
# 				CGI::input({ -value => $PermissionRecord->$_, -size => 25 })
# 			])
# 		);
# 	}
# 	print CGI::end_table();
# 	
# 	#print CGI::br();
# 	print "</td><td valign=\"top\">";
# 	########################################
# 	# Change password section
# 	########################################
# 	my $profRecord = $db->getUser($userID);
# 	my $profName = $profRecord->first_name . " " . $profRecord->last_name;
# 	my $poss = "'s ";
# 	my $pass = " password ";
# 	
# 	print CGI::start_table();
# 	print CGI::Tr(CGI::td(["<b>$profName</b>$poss$pass", CGI::input({ -type => "password", -name => "$userID.password"})]));
# 	print CGI::Tr(CGI::td(["<b>$userName</b>$poss new $pass", CGI::input({ -type => "password", -name => "$editForUserID.password.1"})]));
# 	print CGI::Tr(CGI::td(["Confirm <b>$userName</b>$poss new $pass", CGI::input({ -type => "password", -name => "$editForUserID.password.2"})]));
# 	print CGI::end_table();
# 	print "</td></tr>";
# 	print CGI::Tr(CGI::th(  #FIXME  enable this once it can be handled
# # 		CGI::checkbox({ type => 'checkbox',
# # 								name => "change.login",
# # 								label => '',
# #                         		checked => 0
# #         }),
#         "Change login name $editForUserID to ", CGI::input({-name=>'new_login', -value=>''  ,-size=>25})
# 	));
# 	print CGI::end_table();
	
	print CGI::br();

	#print CGI::h4("Sets assigned to $userName");
	# construct url for the form
	my $userDetailPage = $urlpath->new(type =>'instructor_user_detail',
					                       args =>{
						                             courseID => $courseID,
						                             userID   => $editForUserID, #FIXME eventually this should be a list??
	                }
	);
	my $userDetailUrl = $self->systemLink($userDetailPage,authen=>0);

	my %GlobalSetRecords = map { $_->set_id => $_ } $db->getGlobalSets($db->listGlobalSets());
	my @UserSetRefs = map { [$editForUserID, $_] } sortByName(undef, @UserSetIDs);
	my %UserSetRecords = map { $_->set_id => $_ } $db->getUserSets(@UserSetRefs);
	my @MergedSetRefs = map { [$editForUserID, $_] } sortByName(undef, @UserSetIDs);
	my %MergedSetRecords = map { $_->set_id => $_ } $db->getMergedSets(@MergedSetRefs);
	
	########################################
	# Print warning
	########################################
	print CGI::div({-class=>'ResultsWithError'},
		       "Do not uncheck a set unless you know what you are doing.", CGI::br(),
		       "There is NO undo for unassigning a set.");

	print CGI::p("To change status (scores or grades) for this student for one
	              set, click on the individual set link.");

	print CGI::div({-class=>'ResultsWithError'},"When you uncheck a homework set (and save the changes), you destroy all
		      of the data for that set for this student.   If you
		      reassign the set, the student will receive a new version of each problem.
		      Make sure this is what you want to do before unchecking sets."
	);
	########################################
	# Assigned sets form
	########################################

	print CGI::start_form( {method=>'post',action=>$userDetailUrl, name=>'UserDetail'}),"\n";
	print $self->hidden_authen_fields();
	print CGI::p(CGI::submit(-name=>'save_button',-label=>'Save changes',));
	
	print CGI::start_table({ border=> 1,cellpadding=>5}),"\n";
	print CGI::Tr(
		CGI::th({align=>'center',colspan=>3}, "Sets assigned to $userName ($editForUserID)")
	),"\n";
	print CGI::Tr(
		CGI::th({ -align => "center"}, [
			"Assigned",
			"Edit set for $editForUserID",
			"Dates",
		])
	),"\n";
	foreach my $setID (sortByName(undef, $db->listGlobalSets())) {
		my $GlobalSetRecord = $GlobalSetRecords{$setID};
		my $UserSetRecord = $UserSetRecords{$setID};
		my $MergedSetRecord = $MergedSetRecords{$setID};
		my $setListPage = $urlpath->new(type =>'instructor_set_detail',
					args =>{
						courseID => $courseID,
						setID    => $setID
	                }
	    );
		my $url = $self->systemLink($setListPage,
		                      params =>{effectiveUser => $editForUserID,
		                                editForUser   => $editForUserID,
		});

		print CGI::Tr(
			CGI::td({ -align => "center" }, [
				CGI::checkbox({ type => 'checkbox',
								name => "set.$setID.assignment",
								label => '',
								value => 'assigned',
                        		checked => (defined $MergedSetRecord)
                }),
				defined($MergedSetRecord) ? CGI::b(CGI::a({href=>$url},$setID, ) ) : CGI::b($setID, ),
				join "\n", $self->DBFieldTable($GlobalSetRecord, $UserSetRecord, $MergedSetRecord, "set", $setID, \@dateFields,$rh_dateFieldLabels),
			])
		),"\n";
	}
	print CGI::end_table(),"\n";
	print CGI::p(CGI::submit(-name=>'save_button',-label=>'Save changes',));
	print CGI::end_form(),"\n";
	########################################
	# Print warning
	########################################

	CGI::div( {class=>'ResultsWithError'},
				"There is NO undo for this function.  
				 Do not use it unless you know what you are doing!  When you unassign
				 sets using this button, or by unchecking their set names, you destroy all
				 of the data for those sets for this student."
	);


#	print CGI::start_table();
#	print CGI::Tr(
#		CGI::th({ -align => "center"},[
#			"Assigned",
#			"Set Name",
#			"Opens",
#			"Answers Due",
#			"Answers Available",
#		])
#	);
				
#	foreach my $setID (sortByName(undef, @UserSetIDs)) {
#		my $MergedSetRecord = $MergedSetRecords{$setID};
#		print CGI::Tr(
#			CGI::td({ -align => "center" }, [
#				CGI::checkbox({checked => (defined $MergedSetRecord)}),
#				$setID,
#				CGI::checkbox() .
#				CGI::input({ -value => $self->formatDateTime($MergedSetRecord->open_date), -size => 25}),
#				CGI::checkbox() .
#				CGI::input({ -value => $self->formatDateTime($MergedSetRecord->due_date), -size => 25}),
#				CGI::checkbox() .
#				CGI::input({ -value => $self->formatDateTime($MergedSetRecord->answer_date), -size => 25}),
#			])
#		);
#	}
	return '';
}

sub checkDates { 
	my $self         = shift;
	my $setRecord    = shift;
	my $setID        = shift;
	my $r            = $self->r;
	my %dates = ();
	my $error_undefined_override = 0;
	my $numerical_date=0;
	my $error        = 0;
	foreach my $field (@{DATE_FIELDS_ORDER()}) {  # check that override dates can be parsed and are not blank
		$dates{$field} = $setRecord->$field;
		if (defined  $r->param("set.$setID.$field.override") ){
			eval{ $numerical_date = $self->parseDateTime($r->param("set.$setID.$field"))};
			unless( $@  ) {
					$dates{$field}=$numerical_date;
			} else {
					$self->addbadmessage("&nbsp;&nbsp;* Badly defined time for set $setID $field. No date changes made:<br/>$@");
					$error = 1;
			}
		}
			

	}
	return {%dates,error=>1} if $error;    # no point in going on if the dates can't be parsed.
	
	my ($open_date, $due_date, $answer_date) = map { $dates{$_} } @{DATE_FIELDS_ORDER()};

	if ($answer_date < $due_date || $answer_date < $open_date) {		
		$self->addbadmessage("Answers cannot be made available until on or after the due date in set $setID!");
		$error = 1;
	}
	
	if ($due_date < $open_date) {
		$self->addbadmessage("Answers cannot be due until on or after the open date in set $setID!");
		$error = 1;
	}
	
	# make sure the dates are not more than 10 years in the future
	my $curr_time = time;
	my $seconds_per_year = 31_556_926;
	my $cutoff = $curr_time + $seconds_per_year*10;
	if ($open_date > $cutoff) {
		$self->addbadmessage("Error: open date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	if ($due_date > $cutoff) {
		$self->addbadmessage("Error: due date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	if ($answer_date > $cutoff) {
		$self->addbadmessage("Error: answer date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	
	
	if ($error) {
		$self->addbadmessage("No date changes were saved!");
	}
	return {%dates,error=>$error};
}

sub DBFieldTable {
	my ($self, $GlobalRecord, $UserRecord, $MergedRecord, $recordType, $recordID, $fieldsRef,$rh_fieldLabels) = @_;
	
	return CGI::div({class => "ResultsWithError"}, "No record exists for $recordType $recordID") unless defined $GlobalRecord;
	
	my $r = $self->r;
	my @fields = @$fieldsRef;
	my @results;
	foreach my $field (@fields) {
		my $globalValue = $GlobalRecord->$field;
		my $userValue = defined $UserRecord ? $UserRecord->$field : $globalValue;
		my $mergedValue  = defined $MergedRecord ? $MergedRecord->$field : $globalValue;
		push @results, 
			[$rh_fieldLabels->{$field},
			 defined $UserRecord ? 
				CGI::checkbox({
					type => "checkbox",
					name => "$recordType.$recordID.$field.override",
					label => "",
					value => $field,
					checked => $r->param("$recordType.$recordID.$field.override") || ($mergedValue ne $globalValue ? 1 : 0)
				}) : "",
				defined $UserRecord ? 
					(CGI::input({ -name=>"$recordType.$recordID.$field",
					              -value => $userValue ? $self->formatDateTime($userValue) : "", 
					              -size => 25})
					) : "",
				$self->formatDateTime($globalValue),				
			]
			
	}

	my @table;
	foreach my $row (@results) {
		push @table, CGI::Tr(CGI::td({-align => "center"}, $row));
	}
	
	return (CGI::start_table({border => 0}), @table, CGI::end_table());
}

1;
