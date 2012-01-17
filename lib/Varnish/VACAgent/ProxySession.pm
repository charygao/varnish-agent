package Varnish::VACAgent::ProxySession;

use Moose;
use 5.010;
use Data::Dumper;

use Varnish::VACAgent::VarnishClientConnection;
use Varnish::VACAgent::VarnishResponse;



has id => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has vac => (
    is => 'ro',
    isa => 'Varnish::VACAgent::VACClient',
    required => 1,
);

has varnish => (
    is => 'rw',
    isa => 'Maybe[Varnish::VACAgent::VarnishClientConnection]',
    lazy_build => 1,
);

has id => (
    is => 'rw',
    isa => 'Int',
    required => 1,
);



with 'Varnish::VACAgent::Role::Configurable';
with 'Varnish::VACAgent::Role::Logging';



sub BUILD {
    my $self = shift;

    $self->varnish(); # Touch it into existence
}



sub _build_varnish {
    my $self = shift;
    
    $self->debug("Creating varnish client connection");
    my $varnish = $self->_connect_to_varnish();
    my $response = $varnish->response();

    if (! ($response->is_ok() || $response->is_auth())) {
        die "Bad varnish server initial response: ", $response->status(),
            " ", $response->message();
    }
    
    $self->debug("_build_varnish, response: ", Dumper($response->message()));
    $self->vac->put($response->message());
    
    return $varnish;
}



sub _connect_to_varnish {
    my $self = shift;
    
    my $id = $self->id();
    my $address = $self->_config->varnish_address();
    my $port    = $self->_config->varnish_port();
    my $varnish =
        Varnish::VACAgent::VarnishClientConnection->new(proxy_session_id => $id,
                                                        address => $address,
                                                        port => $port);
    $self->varnish($varnish);
    
    return $varnish;
}



sub terminate {
    my $self = shift;
    
    $self->debug("ProxySession->terminate");
    $self->vac->terminate();
    $self->varnish->terminate();
}



# A VAC request should result in a new connection to Varnish dedicated
# to this VAC session. As long as neither VAC nor Varnish has closed
# their end of the socket, this session should continue.
#
# It would be wrong to create a new connection to varnish every time
# the VAC transmits data.
# 
# Maybe create a VACToVarnishSession to hold pointers to VAC and
# Varnish connections?
#
# I think I can't use promises, I don't know in what order they will
# request and respond - or do I? Humm - maybe I do anyway - results
# from jobs are to be sent to a RESTful url, so nothing on the CLI.
#
# Ok, try with promises first, if it doesn't work, then I will just
# have to use callbacks instead. Either have Agent keep track of which
# VarnishClientConnection belongs to which VACClient, or make a new
# VACVarnishSession or something.


sub handle_vac_request {
    my $self = shift;

    my $vac = $self->vac();
    my $varnish = $self->varnish();
    my $response;

    $varnish->put($vac->data());
    
    $response = $varnish->response();
    $self->debug("handle_vac_request, status: ", $response->status(),
                 ", message: ", $response->message());

    $vac->put($response->message());
}



sub receive_command_2 {
    my ($self, $socket, $authenticated) = @_;
    
    $self->debug("authenticated=$authenticated");

    # my $line = <$socket>;
    # $self->debug("C->A: ".pretty_line($line));
    # $line = chomp_line($line);
    # my $tmp = $line;
    # my $heredoc = undef;
    # if ($authenticated && $tmp =~ s/ << (\w+)$//) {
    #     # Here-document
    #     my $token = $1;
    #     my $part;
    #     while (1) {
    #         $part = <$socket>
    #     	or die $!;
    #         last if (chomp_line($part) eq $token);
    #         $heredoc .= $part;
    #     }
    # }
    # my @args = unquote($tmp);
    # my $command = shift @args;
    # push @args, $heredoc if defined $heredoc;
    # return {
    #     line => $line,
    #     command => $command,
    #     args => \@args,
    #     heredoc => defined $heredoc ? 1 : 0,
    # };
}



sub DEMOLISH {
    my $self = shift; 
   
    $self->debug("ProxySession ", $self->id(), " demolished");
}



1;

__END__



=head1 AUTHOR

 Sigurd W. Larsen

=cut