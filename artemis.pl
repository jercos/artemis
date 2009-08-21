#!/usr/bin/perl
use Artemis;
# main::DEBUG was probably a horrible idea, and I should write it out, but it's rather hardcoded.
# undef or false for a slightly quieter artemis.
$main::DEBUG = 1;
# internals can be overriden in new.
# dereferencing an artemis object would in theory clone the running bot with filehandles intact.
# TODO: use this to allow running changes to Artemis.pm
# note that cloning an Artemis object like this and calling Process on both may have unforseen consequences.
my $art = Artemis->new;
# A little preperation. if this gets closed, we want to save the user db first.
# Obviously, this will need to be something more robust. 
# TODO: make this not suck :P
$SIG{INT}=sub{exit};
END{
	open USERDB, ">users.db";
	for(keys %{$art->{users}}){
		print USERDB pack("Z*Z*n",$_,$art->{pass}{$_},$art->{users}{$_}),"\n" unless lc($_) eq "root";
	}
}
# And now, we load the user db. note the simple pack/unpack methodology for the example.
# if one so desired, one could tie a hashref to users and pass instead.
open USERDB, "<users.db";
while(<USERDB>){
	my($user,$pass,$level) = unpack("Z*Z*n",$_);
	print "adding $user at $level hash of $pass\n";
	next if lc $user eq 'root';
	$art->{users}{$user} = $level;
	$art->{pass}{$user} = $pass;
}
close USERDB;
# example connect line. it is quite important to me that it is simple to connect to multiple hosts, 
# so type and host are all that are needed. nick and autojoin, however, are quite useful.
# pass may well serve the bot owner, but since this is publicly accessable, I think I'll leave it off :P
$art->connect(
	{type=>"term"},
	{type=>"irc",host=>"irc.foonetic.net",nick=>"artemis2",autojoin=>["#test","#bots","#boats","#xkcd-religion"]},
#	{type=>"irc",host=>"irc.foonetic.net",nick=>"artemis2",autojoin=>["#test"]},
#	{type=>"jabber",host=>"jercos.dyndns.org",nick=>"artemis",pass=>"noonebutme"},
);
# a simple loop over Process() is all that is strictly neccisary, however Process() does not block.
# feel free to perform nonblocking or short-blocking tasks at the same time. 
while(1){
$art->Process();
select(undef,undef,undef,0.2)
}
