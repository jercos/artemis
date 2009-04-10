#!/usr/bin/perl
push @INC, ".";
use Artemis;
$main::DEBUG = 1;
my $art = Artemis->new;
$art->connect(
	{type=>"term"},
	{type=>"irc",host=>"irc.foonetic.net",nick=>"artemis2",autojoin=>["#test","#bots","#boats"]},
	{type=>"irc",host=>"irc.foonetic.net",nick=>"artemis2_",autojoin=>["#test"]},
#	{type=>"jabber",host=>"jercos.dyndns.org",nick=>"artemis",pass=>"noonebutme"},
);
while(1){
$art->Process();
select(undef,undef,undef,0.2)
}
