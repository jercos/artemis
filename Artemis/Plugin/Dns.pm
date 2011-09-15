package Artemis::Plugin::Dns;
use Digest::SHA qw(sha1_base64);
use Sys::Hostname;
use Getopt::Long;
use Text::ParseWords qw(shellwords);
use Net::DNS;
sub new{
	my $class = shift;
	my $self = {
		dns => Net::DNS::Resolver->new(tcp_timeout => 15, udp_timeout => 10),
	};
	return bless($self,$class);
}
sub input{
	my $self = shift;
	my($conn,$msg) = @_;
	return unless $msg->pm && $msg->text =~ /^dns( .*)?$/;
	return if time - $self->{main}{floodprot}{$msg->token} < 4;
	$self->{main}{floodprot}{$msg->token}=time;
	local @ARGV = shellwords($1);
	my $q;
	my $s = "127.0.0.1";
	GetOptions('query|q=s' => \$q, 'server=s' => \$s);
	push @ARGV, hostname unless @ARGV;
	for my $host (@ARGV){
		my $result;
		$host.="." if $host !~ /\./;
		my $dns = $self->{dns};
		if($s eq "recurse"){
			$dns = Net::DNS::Resolver::Recurse->new;
		}else{
			$dns->nameservers($s);
		}
		if($q){
			$result = eval{$dns->send($host,$q)};
			if($@){
				$conn->message($msg->to,$msg->user.": Failure. Is that a real DNS record type?");
				next;
			}
		}else{
			$result = $dns->send($host,"AAAA");
			if($result && !scalar($result->answer)){
				$result = $dns->send($host);
			}
		}
		unless($result){
			$conn->message($msg->to,$msg->user.": Failure. ".$self->{dns}->errorstring);
			next;
		}
		my @a = $result->answer;
		unless(@a){
			(my $str = ($result->question)[0]->string) =~ s/\t/    /g;
			$conn->message($msg->to,$msg->user.": $host returned no records for \"$str\"");
			next;
		}
		my $output=$host;
		{
			my %a;
			local $_;
			for my $record(@a){
				if(uc $record->type eq "SOA"){
					push @{$a{"SOA"}}, $record->mname . " " . $record->rname . " Serial: " .$record->serial;
				}else{
					push @{$a{$record->type}}, $record->rdatastr;
				}
			}
			$output .= " $_ ".join ",",@{$a{$_}} for keys %a;
		}
		$output =~ tr/\r\n\t//d;
		$conn->message($msg->to,$msg->user.": $output");
	}
}
1;
