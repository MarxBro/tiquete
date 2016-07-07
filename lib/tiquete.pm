package tiquete;
use Dancer2;

#use utf8;
use POSIX q/strftime/;
#use Pod::Usage;
use File::Slurp;
use feature             "say";
use Data::Uniqid        "luniqid";
#use Email::MIME;
use List::MoreUtils     "first_index";

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

# La fecha es automática.
# El estado y la devolución son agregados poe el admin.
#El sistema tiene que mandar mails cuando:
#* se abre un nuevo ticket (A los admines + confirmacion para el user?)
#* se cierra un nuevo ticket (Al user)

#Usar CSV es malo, pero es mas facil pa que la gilada despues use excel y se arregle


#Hacer:
#* Mostrar todos los tickets al admin
#* Logs to file: implementar
#* Limites de tickets permitidos
#* Mailing -> todo!


#-------------------------------------------------------
#                                           VARIABLES
#-------------------------------------------------------
my $hoy_ahora = strftime ("%d / %B / %Y %H:%M:%S",localtime(time()));
#my $TIK = read_file ($config->{tiquete}{data});
my %T = ();
my @limitados = ();
my @fields_csv = qw( 0ID 1mail 2nombre 3dominio 4importancia 5descripcion 6fecha 7estado 8devolucion );
my $tik_id = 3;
my @csv_file = ();
my $sep = '|||';
my $go_back_linky = '<br /><input action="action" type="button" value="Volver" onclick="history.go(-1);" /><br />';

our $VERSION = '0.1';

######################################################################
#/ ___|  | | | | | __ )  / ___| 
#\___ \  | | | | |  _ \  \___ \ 
# ___) | | |_| | | |_) |  ___) |
#|____/   \___/  |____/  |____/ 
######################################################################

sub leer_db {
    my @archivo = read_file(config->{'data'}, { binmode => ':utf8'});
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
    #my $email = shift;
    my $email = $_[0];
    my $username = qr'[a-z0-9]([a-z0-9.]*[a-z0-9])?';
    my $domain   = qr'[a-z0-9.-]+';
    if ($email =~ m/^$username[@]+$domain$/gxi){
        return 1;
    } else {
        return 0;
    }
}

# Salio de aca: http://learn.perl.org/examples/email.html
sub mailing {
    my $emisor = config->{'mail_send_from'};;
    my $recipiente = $_[0];
    my $mensaje = $_[1]; # Lineas separadas con "\n" !
    my $asunto = $_[2];
    my $encoding = config->{'mail_send_encoding'};
    my $charset = config->{'mail_send_charset'};
    my $rt = config->{'mail_send_reply'};
    # first, create your message
    my $message = Email::MIME->create(
        header_str => [
            From     => $emisor,
            To       => $recipiente,
            Subject  => $asunto,
            #Reply-To => $rt,
        ],
        attributes => {
            encoding => $encoding,
            charset  => $charset,
        },
        body_str => $mensaje,
    );

    # send the message
    use Email::Sender::Simple qw(sendmail);
    sendmail($mensaje);
}

sub give_me_id {
    return luniqid();
}

sub join_lines {
    my $i = shift;
    $i =~ s/\r//g;
    $i =~ s/\n/<br\/>/g;
    return $i;
}

sub split_lines {
    my $i = shift;
    $i =~ s/<br \/>/\n/g;
    return $i;
}

sub get_mails_with_open_tiks {
    my %temp = ();
    my @lims = ();
    foreach my $k (keys %T){
        if ($T{$k}{'7estado'} !~ m"cerrado"gi){
            my $mail_ppl = $T{$k}{'1mail'};
            $temp{ $mail_ppl }++;
            push ( @lims, $mail_ppl ) if ( $temp{$mail_ppl} == config->{'max_tiks_per_mail'} );
        }
    }
    @limitados = @lims;
}

sub gente_limitada {
    my $b = shift;
    get_mails_with_open_tiks();
    return ( $b ~~ @limitados );
}

######################################################################
#|  _ \  / \  | \ | |/ ___| ____|  _ \  |  _ \ / \  |  _ \_   _|
#| | | |/ _ \ |  \| | |   |  _| | |_) | | |_) / _ \ | |_) || |  
#| |_| / ___ \| |\  | |___| |___|  _ <  |  __/ ___ \|  _ < | |  
#|____/_/   \_\_| \_|\____|_____|_| \_\ |_| /_/   \_\_| \_\|_|  
######################################################################

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

    #Excepciones
    unless (valid_mail($email)){
        my $titu = 'Error: e-mail';
        my $ms = 'Direccion de e-mail inválida. Intente nuevamente.';
        status 'bad_request';
        return template 'simple', { titulo => $titu, mensaje => $ms };
    } 
    if (length($descripcion) < config->{'min_longitud_descripcion_tik'}){
        my $titu = 'Error: descripción';
        my $ms = 'La descripción es demasiado corta. Intente nuevamente.'; 
        status 'bad_request';
        return template 'simple', { titulo => $titu, mensaje => $ms };
    }
    if (gente_limitada($email)){
        my $titu = 'Error: Muchos Tickets Abiertos';
        my $ms = 'Usted alcanzó el límite máximo de tickets abiertos posible.'; 
        status 'bad_request';
        return template 'simple', { titulo => $titu, mensaje => $ms };
    }

    #Hacer La linea del CSV.
    my $ln = 
        $ID_new     . $sep . 
        $email      . $sep . 
        $nombre     . $sep . 
        $dominio    . $sep . 
        $importancia . $sep . 
        join_lines($descripcion) . 
        $sep . $fecha_ahora . "\n";

    #al final
    write_db($ln);
    redirect "/ticket/$ID_new";
};

#get '/subido/:ID' => sub {
    #my $tik_id = params->{'ID'} || template '404', { path => request->path };
    #my $tik_uri = '/ticket/' . $tik_id;
    #template 'subido', { URL_NN => $tik_uri };
#};


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

    #Defaults
    my $EST  = $T{$tik_id}{'7estado'} || config->{'default_tik_st'}; 
    my $DEVO = $T{$tik_id}{'8devolucion'} || config->{'default_tik_dev'};
    #'Ticket asignado para su pronta resolución.'; 
    my $colorin_estado = 'red';

    if ($EST eq 'cerrado'){
        $colorin_estado = 'green';
    } elsif ($EST eq "config->{'default_tik_st'}"){
        $colorin_estado = 'red';
    } else {
        $colorin_estado = 'yellow';
    }

    template 'tik', { 
        Nombre =>       $T{$tik_id}{'2nombre'}, 
        Dominio =>      $T{$tik_id}{'3dominio'}, 
        Contacto =>     $T{$tik_id}{'1mail'}, 
        Importancia =>  $T{$tik_id}{'4importancia'}, 
        Descripcion =>  join_lines($T{$tik_id}{'5descripcion'}), 
        Fecha =>        scalar localtime $T{$tik_id}{'6fecha'}, 
        ID =>           $T{$tik_id}{'0ID'}, 
        Estado =>       $EST,
        Devolucion =>   $DEVO,
        precio =>       config->{'precio_hora_soporte'}, 
        color =>        $colorin_estado,
    };
};

######################################################################
#                                                       Admins
get '/all/:pass' => sub {
    my $u_pa = params->{'pass'};
    unless ($u_pa eq config->{pass_admin}){
        status 'not_found';
        template '404', { path => request->path };
    }

    my %abiertos = ();
    my %cerrados = ();
    foreach my $k (keys %T){
        if ($T{$k}{'7estado'} !~ m"cerrado"gi){
            $abiertos{$k} = $T{$k};
        } else {
            $cerrados{$k} = $T{$k};
        }
    }
    template 'all', { abiertos => \%abiertos, cerrados => \%cerrados, fecha => $hoy_ahora};
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
    
    my $EST  = $T{$tik_id}{'7estado'} || config->{'default_tik_st'}; 
    my $DEVO = $T{$tik_id}{'8devolucion'} || config->{'default_tik_dev'};
    
    my $colorin_estado = 'red';
    if ($EST eq 'cerrado'){
        $colorin_estado = 'green';
    } elsif ($EST eq "config->{'default_tik_st'}"){
        $colorin_estado = 'red';
    } else {
        $colorin_estado = 'yellow';
    }
    
    my $aviso = config->{'devolucion_primera'};
    unless ($DEVO){
        $aviso = config->{'devolucion_retoques'};
    }

    if ($u_pa eq config->{pass_admin}){
        template 'fix_ticket', { 
            Nombre =>       $T{$tik_id}{'2nombre'}, 
            Dominio =>      $T{$tik_id}{'3dominio'}, 
            Contacto =>     $T{$tik_id}{'1mail'}, 
            Importancia =>  $T{$tik_id}{'4importancia'}, 
            Descripcion =>  join_lines($T{$tik_id}{'5descripcion'}), 
            Fecha =>        scalar localtime $T{$tik_id}{'6fecha'}, 
            ID =>           $T{$tik_id}{'0ID'}, 
            #path =>         request->path, 
            pass => $u_pa,
            color =>        $colorin_estado,
            estado => $EST,
            devolucion => $DEVO,
            aviso => $aviso,
        };
    } else {
        status 'not_found';
        template '404', { path => request->path };
    }
};

post '/fix' => sub{
    my $tik_id = params->{'ID'};
    my $u_pa = params->{'pass'};
    my $estado = params->{'ESTADO'};
    my $devolucion = join_lines(params->{'Devo'});

    if ($u_pa eq config->{pass_admin}){
        #do stuff
        my $index_of_ticket = first_index {/$tik_id/} @csv_file;
        my $ln_par_laburar  = $csv_file[$index_of_ticket];
        #sacar los saltos de línea que pueda tener: usamos un puto CSV!
        $ln_par_laburar     =~ s/\r//g;
        $ln_par_laburar     =~ s/\n//g;
        my $append_to_csv   = $sep . $estado . $sep . $devolucion . "\n";
        $ln_par_laburar     .= $append_to_csv;
        $csv_file[$index_of_ticket] = $ln_par_laburar;
        # al final: escribir de nuevo y redireccionar (el hook recarga la data)
        write_file(config->{'data'}, { binmode => ':utf8'}, @csv_file);
        redirect "/ticket/$tik_id";
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



true;
