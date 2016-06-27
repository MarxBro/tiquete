package tiquete;
use Dancer2;

use POSIX q/strftime/;
#use Pod::Usage;
use Data::Dumper;
use File::Slurp;
use utf8;
use feature "say";
use Data::Uniqid "luniqid";

=pod

=encoding utf8

=head1 SYNOPSIS

Ticket system.

=cut

# Data estructure
# 0     ID
# 1     mail
# 2     nombre
# 3     dominio
# 4     importancia
# 5     descripcion
# --6   fecha
# ++7   estado
# ++8   devolucion


#-------------------------------------------------------
#                                           VARIABLES
#-------------------------------------------------------
my $hoy_ahora = strftime ("%d / %B / %Y %H:%M:%S",localtime(time()));
#my $TIK = read_file ($config->{tiquete}{data});
my %T = ();
my @fields_csv = qw( 0ID 1mail 2nombre 3dominio 4importancia 5descripcion 6fecha 7estado 8devolucion );
my $tik_id = 3;
my @csv_file = ();

our $VERSION = '0.1';

#S U B S
sub leer_db {
    my @archivo = read_file(config->{'data'});
    @csv_file = @archivo;
    foreach my $ln (@archivo){
        next if $ln =~ /^id/i;
        my @f = split (/\|{3}/,$ln);
        my %Tt;
        foreach my $nn (0 .. $#fields_csv){
            $Tt{$fields_csv[$nn]} = $f[$nn];
            }
        my $tref = \%Tt;
        my $id = $f[0];
        $T{$id} = $tref;
    }
}

sub write_db {
    my $line_to_write = $_[0];
    push(@csv_file,$line_to_write);
    write_file(config->{'data'}, { binmode => ':utf8'}, @csv_file);
}

#if (valid_mail("s@shshsh.com")){ print "OK!"; } 
sub valid_mail {
    my $email = shift;
    my $username = qr/[a-z0-9]([a-z0-9.]*[a-z0-9])?/;
    my $domain   = qr/[a-z0-9.-]+/;
    my $regex = $email =~ /^$username\@$domain$/;
    return $regex;
}

sub give_me_id {
    return luniqid();
}


#------------------------       Hook

hook before => sub {
    leer_db();
    var data => %T;
};

######################################################################
#                                                       Home
get '/' => sub {
    template 'home', { fecha => $hoy_ahora, debug => \%T };
};

######################################################################
#                                                        Subir
get '/nuevo' => sub {
    template 'new';
};
post '/nuevo' => sub {
    my $email = params->{'e-mail'};
    my $nombre = params->{'Nombre'};
    my $dominio = params->{'Dominio'};
    my $importancia = params->{'Importancia'};
    my $descripcion = params->{'Desc'};

    my $ID_new = give_me_id();
    my $fecha_ahora = time();

    unless (valid_mail($email)){
        return '<html><body><h2>Direccion de e-mail inválida. Intente nuevamente.</h2></body></html>';
    }

    #Hacer La linea del CSV.
    my $sep = '|||';
    my $ln = 
    $ID_new     . $sep . 
    $email      . $sep . 
    $nombre     . $sep . 
    $dominio    . $sep . 
    $importancia . $sep . 
    $descripcion . $sep . 
    $fecha_ahora;

    #al final
    write_db($ln);
    redirect "/subido/$ID_new";
};

get '/subido/:ID' => sub {
    my $tik_id = params->{'ID'} || template '404', { path => request->path };
    my $tik_uri = '/ticket/' . $tik_id;
    template 'subido', { URL_NN => $tik_uri };
};


######################################################################
#                                                       Leer
post '/ticket' => sub {
    my $tik_id = params->{'ID'};
    redirect "/ticket/$tik_id";
};

get '/ticket/:ID' => sub {
    my $tik_id = params->{'ID'};
    unless ($T{$tik_id}){
        status 'not_found';
        template '404', { path => request->path };
    }
    template 'tik', { ID => $tik_id };
};

######################################################################
#                                                       Admins
get '/all' => sub {
    template 'all';
};
get '/all/cli' => sub {
    my $result;
    foreach my $e (@csv_file){
        $e =~ s/\|{3}/\t/g;
        $result .= $e ;
    }
    return $result;
};

# Rutas para dar una tarea por finalizada y agregar devolución
# REQUIEREN Pass !
get '/ticket/:ID/done/:pass' => sub{
    my $tik_id = params->{'ID'};
    my $u_pa = params->{'pass'};
    template 'fix_ticket.tt';
};
post '/ticket/:ID/done/:pass' => sub{
    my $tik_id = params->{'ID'};
    my $u_pa = params->{'pass'};
    template 'fix_ticket.tt';
    if ($u_pa eq config->{tiquete}{pass_admin}){
        #do stuff
        #al final
        redirect '/all';
    } else{
        status 'not_found';
        template '404', { path => request->path };
    }
};


######################################################################
# Regla para agarrar cualquier error o balazo cósmico.
any qr{.*} => sub {
    status 'not_found';
    template '404', { path => request->path };
}; 


#-----------------------------------------------------------------------------#
=pod

=head1 Autor y Licencia.

Programado por B<Marxbro> aka B<Gstv>, distribuir solo bajo la licencia
WTFPL: I<Do What the Fuck You Want To Public License>.

Zaijian.

=cut
#-----------------------------------------------------------------------------#

true;
