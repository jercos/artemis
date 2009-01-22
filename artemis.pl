push @INC, ".";
use Artemis;
$DEBUG = 1;
my $art = Artemis->new;
$art->connect(
	{type=>"term"},
	{type=>"irc",host=>"irc.foonetic.net",nick=>"artemis2",autojoin=>["#boats"]},
#	{type=>"irc",host=>"irc.foonetic.net",nick=>"artemis2_",autojoin=>["#boats"]},
	{type=>"jabber",host=>"jercos.dyndns.org",nick=>"artemis",pass=>"noonebutme"},
);
while(1){
$art->Process();
select(undef,undef,undef,0.2)
}
