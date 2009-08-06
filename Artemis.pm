package Artemis;
use Module::PluginFinder;
use Artemis::Message;
sub new{
	# a simple constructor...
	my $class = shift;
	# keep an array of Artemis::Connection::* types in connections, a DBI handle in facts, and leave room for setting these at creation-time
	my $self = {
		connections=>[],
		facts=>undef,
		modules=>{},
		users=>{root=>65536},
		logins=>{"term://"=>"root"},
		pass=>{},
		@_
		};
	# two arg bless. I don't think anything will ever need to inherit from Artemis, but w/e
	return bless($self,$class);
}
sub connect{
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
	for my $item(@_){
		# called like $art->connect({...}); not $art->connect(...);
		next unless ref($item) eq "HASH";
		eval{
			my $conn = $finder->construct($item->{type},%$item,main=>$self);
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
	my $name = lc shift;
	my $module = "Artemis::Plugin::\u$name";
	my $file = "./Artemis/Plugin/\u$name.pm";
	my $spawn = shift;
	unless(do $file){
		print STDERR "failed to load $module\n$@\n";
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
# called like $self->{main}->incoming($self, Artemis::Message);
sub incoming{
	my $self = shift;
	my $conn = shift;
	my $msg = shift;
	if(exists($self->{logins}{lc $msg->token}) && $msg->token ne "null://"){
		my $username = $self->{logins}{lc $msg->token};
		$msg->auth($username,$self->{users}{$username});
	}
	for my $module(values %{$conn->{modules}}){
		$module->input($conn, $msg);
	}
}
1;
