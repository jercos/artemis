package Artemis::Connection::Irc;
use IO::Socket;
use strict;
sub new{
	my $class = shift;
	my $self = {
		host=>"localhost",	#server to connect to
		port=>"6667",		#port to connect on
		nick=>"artemis",	#nick!user@host, Real name: realname, if you don't get it, ignore these.
		user=>"artemis",
		realname=>"Artemis v2.0, Jeremy Sturdivant (jercos)",
		serverpass=>undef,	#if this is set, a PASS will be sent after USER and NICK. ignore this unless you want an IRCOP bot.
		nickpass=>undef,	#password to send to nickserv. leave it undef to not identify to nickserv
		autoconnect=>1,		#set to a false value to not immediately call $self->connect(), you'll have to call it later.
		onconnect=>sub{	#this will get called on an "end of MOTD" command from the server, or a "no MOTD" error.
			my $self = shift;
			$self->send("JOIN :$_") for @{$self->{autojoin}};
			$self->send("MODE ".($self->{nick})." +B");
			$self->{main}->load($self,"Core");
		},
		sock=>undef,		#this holds an IO::Socket::INET object, or an IO::Handle, or similar. anything that works inside readline()
		autojoin=>[],		#what channels do we want to join automatically?
		modules=>{},		#this will contain Artemis::Plugin::* objects allowed to work with this connection.
					#preferably, each item will be copied from the master list of objects, but optionally one could call the constructor once for each connection
					#this would allow, for exmaple, a factoid module to keep seperate databases between different networks.
					#the format is Perl module name => object, e.g., $foo = Artemis::Plguin::fo->new();$self->{modules}{"Artemis::Plugin::foo"}=$foo
					#this prevents loading modules twice, and allows for easy unloading.
		@_,			#and finally, suck up any key=>value pairs passed in, and overwrite default values.
	};
	bless($self,$class);
	$self->connect() if $self->{autoconnect};
	$self->{autoconnect}=0; #to facilitate cloning.
	return $self;
}
#I think this is self explanitory. disconnect if we're connected, then connect (potentially "reconnect")
sub connect{
	my $self = shift;
	#make sure we're dealing with a dead socket.
	$self->disconnect if defined($self->{sock}) && $self->{sock}->connected();
	#make a new socket
	$self->{sock} = IO::Socket::INET->new(
		PeerAddr=>$self->{host},
		PeerPort=>$self->{port},
		Blocking=>0,
	);
	#add our new socket to the select loop
	select('','','',0.1) while eof($self->{sock});
	$self->send("USER ".$self->{user}." - - :".$self->{realname},"NICK ".$self->{nick});
}
#we're done, y'all hear?
sub disconnect{
	my $self = shift;
	$self->send("QUIT :disconnect called :(\n");
	$self->{sock}->close();
}
#call this every once in a while, a second or two is suitable, but this should return in under a quarter of a second unless the socket was opened blocking.
sub Process{
	my $self = shift;
	if(defined(my $line = readline($self->{sock}) )){
		$line .= readline($self->{sock}) while !chomp $line;
		$self->irc($line);
	}
}
#a raw send, for exposing to the outside world, and shortening. Never call a Connection module's send() without checking the ref() to make sure it matches the protocol you expect.
sub send{
	my $self = shift;
	return 0 unless defined $self->{sock};
	for(@_){ # I like this better than map{}@_, tbh.
		printf STDERR "%02d:%02d:%02d  <-%s" ,(localtime)[2,1,0] ,$_;
		print {$self->{sock}} "$_\n";
		print "\n";
	}
}
#data headed outward to the network. this defines the scheme for extra data for Artemis::outgoing
sub message{
	my $self = shift;
	my($replyto, $msg) = @_;
	$self->send("PRIVMSG $replyto :$_") for split(/[\r\n]+/,$msg);
}
#this now does the actual parsing of incoming messages :)
sub irc{
	my $self = shift;
	my $data = shift;
	$data =~ s/[\r\n]//g;
	my($special,$main,$longarg) = split(/:/,$data,3);
	printf STDERR "%02d:%02d:%02d special data: '%s'\n",(localtime)[2,1,0],$data if $special;
	return $self->send($data) if $data =~ s/^PING/PONG/;
	return $self->{sock}->close() if $data =~ /^ERROR/;
	my($mask,$command,@args) = split(/ +/,$main);
	my($nick, $user, $host) = ($mask,"@",$mask);
	if($mask =~ /!/){
		($nick, $user, $host) = $mask =~ /^([^!]+)!([^@]+)@(.*)$/;
	}
	if($command eq "PRIVMSG"){
		if($longarg =~ s/^\x01ACTION (.*?)\x01?$/$1/){
			printf STDERR "%02d:%02d:%02d * %s %s\n",(localtime)[2,1,0],$nick,$longarg;
		}elsif($longarg =~ s/^\x01([^ ]+)(.*?)\x01?$/$2/){
			printf STDERR "%02d:%02d:%02d CTCP %s from %s: %s\n",(localtime)[2,1,0],$1,$nick,$longarg;
			return;
		}else{
			printf STDERR "%02d:%02d:%02d <%s> %s\n",(localtime)[2,1,0],$nick,$longarg;
		}
		my $pm = $args[0] eq $self->{nick};
		my $replyto = $pm ? $nick : $args[0];
		$self->{main}->incoming($self,$nick,$longarg,$pm,$replyto,"irc://".$self->{nick}."@".$self->{host}.":".$self->{port}."/#".$mask);
	}elsif($command eq "376" or $command eq "422"){
		$self->{onconnect}->($self);
	}elsif($command eq "NOTICE"){
		printf STDERR "%02d:%02d:%02d -%s- %s\n",(localtime)[2,1,0],$nick,$longarg;
	}elsif($command eq "JOIN"){
		printf STDERR "%02d:%02d:%02d -!- %s [%s] has joined %s\n",(localtime)[2,1,0],$nick,$mask,$longarg;
		$self->send("MODE $longarg +v $nick");
	}elsif($command eq "372" || $command eq "375"){
		printf STDERR "%02d:%02d:%02d MOTD: %s\n",(localtime)[2,1,0],$longarg;
	}elsif($command eq "NICK"){
		if($nick eq $self->{nick}){
			$self->{nick} = $longarg;
			printf STDERR "%02d:%02d:%02d changed nicks to %s\n",(localtime)[2,1,0], $longarg;
		}else{
			printf STDERR "%02d:%02d:%02d * %s is now known as %s\n",(localtime)[2,1,0],$nick,$longarg;
		}
	}else{
		printf STDERR "%02d:%02d:%02d  ->%s\n",(localtime)[2,1,0],$data;
	#	print STDERR "++++ TODO: impliment '$command'\n";
	}
}
1;
