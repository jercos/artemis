push @INC, ".";
use Artemis;
$DEBUG = 1;
my $art = Artemis->new;
$art->connect(
	{type=>"irc",host=>"irc.foonetic.net"},
#	{type=>"jabber",host=>"jercos.dyndns.org"},
);
while(1){
$art->Process();
sleep 1;
}
