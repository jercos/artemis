package Artemis;
use Module::PluginFinder;
sub new{
	# a simple constructor...
	my $class = shift;
	# keep an array of Artemis::Connection::* types in connections, a DBI handle in facts, and leave room for setting these at creation-time
	my $self = {connections=>[],facts=>undef,modules=>{},users=>{jercos=>"1000"},logins=>{"term://"=>"jercos"},@_};
	# two arg bless. no clue why, but w/e.
	return bless($self,$class);
}
sub connect{
	# so things don't explode if somone stupid does Artemis::connect(); hopefully.
	my $self = shift;
	# a fairly generic Module::PluginFinder setup, from what I can tell...
	my $finder = Module::PluginFinder->new(
		search_path => 'Artemis::Connection',
		filter => sub {
			my ( $module, $searchkey ) = @_;
			$module->can( $searchkey );
		},
	);
	# so that multiple things can be connected to at once. magical, no?
	for(@_){
		# called like $art->connect({...}); not $art->connect(...);
		next unless ref($_) eq "HASH";
		eval{
			my $conn = $finder->construct($_->{type},%$_,main=>$self);
			push @{$self->{connections}}, $conn if $conn;
		};
		warn $@ if $@;
	}
}
# simply call $obj->Process() for each connection.
sub Process{
	my $self = shift;
	for my $conn (@{$self->{connections}}){
		$conn->Process(0);
	}
}
#this should load a module by name if it's not already loaded, 
sub load{
	my $self = shift;
	my $conn = shift;
	my $module = "Artemis::Plugin::".shift;
	my $spawn = shift;
	eval "use $module;";
	if($@){
		print STDOUT "failed to load $module\n$@\n";
		return 0;
	}
	if(exists($self->{modules}{$module})){
		if($spawn){
			$conn->{modules}{$module} = $module->new();
		}else{
			$conn->{modules}{$module} = $self->{modules}{$module};
		}
	}else{
		$self->{modules}{$module} = $conn->{modules}{$module} = $module->new();
	}
	return 1;
}
# incoming will handle all traffic from Artemis::Connection modules to Artemis::Plugin modules.
# called like $self->{main}->incoming($self, a simple name (e.g. jercos), the message, 
# A true value if this is a private message (as opposed to one from a chatroom), then any data that needs to be passed back to outgoing.);
sub incoming{
	my $self = shift;
	my $conn = shift;
	my $name = shift;
	my $msg = shift;
	my $pm = shift;
	my $replyto = shift;
	my $token = shift;
	my($user,$level)=($name,undef);
	if(exists($self->{logins}{$token})){
		my $username = $self->{logins}{$token};
		($user,$level)=($username,$self->{users}{$username});
	}
	for(values %{$conn->{modules}}){
		$_->input($conn, $replyto, $name, $msg, $pm, $user, $level, $token);
	}
}
1;
