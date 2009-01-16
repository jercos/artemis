package Artemis;
use Module::PluginFinder;
sub new{
	# a simple constructor...
	my $class = shift;
	# keep an array of Artemis::Connection::* types in connections, a DBI handle in facts, and leave room for setting these at creation-time
	my $self = {connections=>[],facts=>undef,modules=>{},@_};
	# two arg bless. no clue why, but w/e.
	return bless($self,$class);
}
sub connect{
	# so things don't explode if somone stupid does Artemis::connect(); hopefully.
	my $self = shift if ref($_[0]);
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
sub load{
	my $self = shift;
	my $conn = shift;
	my $mod = shift;
	my $finder = Module::PluginFinder->new(
		search_path => 'Artemis::Plugin',
		filter => sub {
			my ( $module, $searchkey ) = @_;
			$module->can( $searchkey );
		},
	);
	my $foo = $finder->construct("foo");
}
# incoming will handle all traffic from Artemis::Connection modules to Artemis::Plugin modules.
# called like $self->{main}->incoming($self, a simple name (e.g. jercos), the message, then any data that needs to be passed back to outgoing.);
sub incoming{
	my $self = shift;
	my $conn = shift;
	my $name = shift;
	my $msg = shift;
	# at this point, @_ contains anything, or nothing at the discretion of the Artemis::Connection::* module that should have called this. 
	# this data is unique to every module, and should not be interchanged between modules, unless you know what you (are) doing.
	# if you need to send data accross networks, an Artemis::Plugin should call connection specific send functions.
	# <TODO>loop over modules assigned to $conn, calling $conn->outgoing(message from module, @_) for each one that returns something, instead of this :P </TODO>
	$conn->outgoing($msg,@_);
}
1;
