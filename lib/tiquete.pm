package tiquete;


# |    o               |         
# |--- .,---..   .,---.|--- ,---.
# |    ||   ||   ||---'|    |---'
# `---'``---|`---'`---'`---'`---'
#           |                    
# ------------------------------->>



use Dancer2;
use Dancer2::Plugin::Auth::Extensible;
use v5.20;
use utf8;
use POSIX q/strftime/;
use File::Slurp;
use Data::Uniqid        "luniqid";
use Email::MIME;
use List::MoreUtils     "first_index";

no warnings 'experimental::smartmatch'; # Nobody likes you!


=pod

=encoding utf8

=head1 SYNOPSIS

Script para ticketear como un loco.

La idea es usarlo para dar soporte... Sep.

=head2 Data structure

=over

=item * 0     ID
=item * 1     mail
=item * 2     nombre
=item * 3     dominio
=item * 4     importancia
=item * 5     descripcion
=item * --6   fecha
=item * ++7   estado
=item * ++8   devolucion

=back

La fecha es automática.

El estado y la devolución son agregados poe el admin.

=cut



#-------------------------------------------------------
#                                           VARIABLES
#-------------------------------------------------------
my $hoy_ahora = strftime ("%d / %B / %Y %H:%M:%S",localtime(time()));
#my $TIK = read_file ($config->{tiquete}{data});
my %T = ();
my %M = ();
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
        #Guardar los mails por separado.
        my $mail_ppl = $f[1];
        if ( $M{$mail_ppl} ){
            unless ($id ~~ @{$M{$mail_ppl}}){
                push ( @{$M{$mail_ppl}} , $id);
            }
        } else {
            my @te = ( $f[0] );    
            $M{$mail_ppl} = \@te;
        }
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
            if ( $temp{$mail_ppl} == config->{'max_tiks_per_mail'} ){
                push ( @lims, $mail_ppl );
            }
        }
    }
    @limitados = @lims;
}

sub gente_limitada {
    my $b = shift;
    get_mails_with_open_tiks();
    return ( $b ~~ @limitados );
}

# MAILING FUNCTION PARA DEPLOY   -------------->>>
# Salio de aca: http://learn.perl.org/examples/email.html

=pod

=head2 MAILING

El sistema tiene que mandar mails cuando:

=item * Se abre un nuevo ticket (A los admines + confirmacion para el user?)
=item * Se cierra un nuevo ticket (Al user)

Usar CSV es malo, pero es mas facil pa que la gilada despues use excel y se arregle


#Hacer:
#* Mostrar todos los tickets al admin
#* Logs to file: implementar
#* Limites de tickets permitidos
#* Mailing -> todo!

=cut
sub mailing {
    my $emisor          = config->{'MAILING'}{'mail_send_from'};;
    my $recipiente      = $_[0];
    my $mensaje         = $_[1]; # Lineas separadas con "\n" !
    my $asunto          = $_[2];
    my $encoding        = config->{'MAILING'}{'mail_send_encoding'};
    my $charset         = config->{'MAILING'}{'mail_send_charset'};
    my $rt              = config->{'MAILING'}{'mail_send_reply'};
    
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

sub msgs_when_new_tik {
    my $id_ntk = shift;
    my $asunto = config->{'MAILING'}{'mail_asunto_todos'} . $id_ntk;
    my $url_ntk = $root_url . '/ticket/' . $id_ntk;
    my $user_msg  = config->{'MAILING'}{'mail_tik_inicio'} . "\n" .
        config->{'MAILING'}{'mail_tmpl_id'} . $id_ntk . "\n" .
        config->{'MAILING'}{'mail_tmpl_url'} . $url_ntk .  "\n" .
        config->{'MAILING'}{'mail_tmpl_pie'};
    my $admin_msg = config->{'MAILING'}{'mail_tik_open'} . "\n" . 
        config->{'MAILING'}{'mail_tmpl_id'} . $id_ntk . "\n" .
        config->{'MAILING'}{'mail_tmpl_url'} . $url_ntk .  "\n" .
        config->{'MAILING'}{'mail_tmpl_pie'};
    return ($user_msg, $admin_msg,$asunto);
}
sub msgs_when_closed_tik {
    my $id_ntk = shift;
    my $estado = shift;
    my $asunto = config->{'MAILING'}{'mail_asunto_todos'} . $id_ntk;
    my $url_ntk = $root_url . '/ticket/' . $id_ntk;
    my $user_msg = config->{'MAILING'}{'mail_tik_closed'} . "\n" . 
        config->{'MAILING'}{'mail_tmpl_id'} . $id_ntk . "\n" .
        config->{'MAILING'}{'mail_tmpl_url'} . $url_ntk .  "\n";
    if ($estado =~ m'cerrado'gi) {
        $user_msg .= config->{'MAILING'}{'mail_tmpl_estado_cerrado'} . $url_ntk .  "\n";
    } else {
        $user_msg .= config->{'MAILING'}{'mail_tmpl_estado_soporte'} . $url_ntk .  "\n";
    }
    $user_msg .= config->{'MAILING'}{'mail_tmpl_pie'};
    return ($user_msg,$asunto);
}


#    _   _   _ _____ _   _ 
#   / \ | | | |_   _| | | |
#  / _ \| | | | | | | |_| |
# / ___ \ |_| | | | |  _  |
#/_/   \_\___/  |_| |_| |_|
#                          

sub login_page_handler {
    template 'login';
}

sub permission_denied_page_handler {
    template 'login';
}


######################################################################
#|  _ \  / \  | \ | |/ ___| ____|  _ \  |  _ \ / \  |  _ \_   _|
#| | | |/ _ \ |  \| | |   |  _| | |_) | | |_) / _ \ | |_) || |  
#| |_| / ___ \| |\  | |___| |___|  _ <  |  __/ ___ \|  _ < | |  
#|____/_/   \_\_| \_|\____|_____|_| \_\ |_| /_/   \_\_| \_\|_|  
######################################################################

#    ><(((º> j\--------------------======o       Hook... ja!

hook before => sub {
    leer_db();
    var data => %T;
};

######################################################################
#                                                       Home
get '/' => sub {
    template 'home', { fecha => $hoy_ahora };
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
    if (config->{'MAILING'}{'mail_enable'}){
        my ($m_u, $m_a, $a_mm) = msgs_when_new_tik($ID_new);
        #mail al user
        mailing($email,$m_u,$a_mm);
        #mail al admin
        mailing(config->{'MAILING'}{'mail_webmaster'},$m_a,$a_mm);
    }
    redirect "/ticket/$ID_new";
};


######################################################################
#                                                       Leer
#Vinculeado desde el home
post '/ticket' => sub {
    my $tik_id = params->{'ID'};
    if ("$tik_id" ~~ [ keys %T ]){
        redirect "/ticket/$tik_id";
    } else {
        status 'not_found';
        template '404', { path => request->path . '/' . $tik_id };
    }
};

#Vinculeado desde el home
post '/tickets' => sub {
    my $tik_mail = params->{'mail'};
    if ("$tik_mail" ~~ [ keys %M ]){
        redirect "/clientes/$tik_mail";
    } else {
        status 'not_found';
        template '404', { path => request->path . '/' . $tik_mail };
    }
};

#Evitar que elsistema de tickets renderee cualka
get '/ticket' => sub {
    status 'not_found';
    template '404', { path => request->path };
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
    my $colorin_estado = 'red';

    if ($EST eq 'cerrado'){
        $colorin_estado = 'green';
    } elsif ($EST eq "soporte"){
        $colorin_estado = 'yellow';
    } else {
        $colorin_estado = 'red';
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

# Clientes -->
get '/clientes' => sub {
    status 'not_found';
    template '404', { path => request->path };
};
get '/clientes/:mm' => sub {
    my $mm = params->{'mm'};
    template 'clientes', { 
        ids => $M{$mm} , 
        mail => $mm, 
        max => config->{'max_tiks_per_mail'}, 
    };
};



######################################################################
#                                                       Admins
get '/all' => require_login sub {
    my %abiertos = ();
    my %cerrados = ();
    foreach my $k (keys %T){
        if ($T{$k}{'7estado'}){
            if ($T{$k}{'7estado'} !~ m"cerrado"gi){
                $abiertos{$k} = $T{$k};
            } else {
                $cerrados{$k} = $T{$k};
            }
        } else {
            $abiertos{$k} = $T{$k};
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
get '/ticket/:ID/done' => require_login sub{
    my $tik_id = params->{'ID'};
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

    template 'fix_ticket', { 
       Nombre       =>  $T{$tik_id}{'2nombre'}, 
       Dominio      =>  $T{$tik_id}{'3dominio'}, 
       Contacto     =>  $T{$tik_id}{'1mail'}, 
       Importancia  =>  $T{$tik_id}{'4importancia'}, 
       Descripcion  =>  join_lines($T{$tik_id}{'5descripcion'}), 
       Fecha        =>  scalar localtime $T{$tik_id}{'6fecha'}, 
       ID           =>  $T{$tik_id}{'0ID'}, 
       color        =>  $colorin_estado,
       estado       =>  $EST,
       devolucion   =>  $DEVO,
       aviso        =>  $aviso,
    };
};

post '/fix' => require_login sub {
    my $tik_id = params->{'ID'};
    my $estado = params->{'ESTADO'};
    my $devolucion = join_lines(params->{'Devo'});

    my $index_of_ticket = first_index {/$tik_id/} @csv_file;
    my $ln_par_laburar  = $csv_file[$index_of_ticket];
    $ln_par_laburar     =~ s/\r//g;
    $ln_par_laburar     =~ s/\n//g;
    my $append_to_csv   = $sep . $estado . $sep . $devolucion . "\n";
    $ln_par_laburar     .= $append_to_csv;
    $csv_file[$index_of_ticket] = $ln_par_laburar;
    # al final: escribir de nuevo y redireccionar (el hook recarga la data)
    write_file(config->{'data'}, { binmode => ':utf8'}, @csv_file);
    # Mandar un mail
    if (config->{'MAILING'}{'mail_enable'}){
        my ($m_u, $a_mm) = msgs_when_closed_tik($tik_id, $estado);
        #mail al user
        my $email_user_tik = $T{$tik_id}{'1mail'};
        mailing($email_user_tik,$m_u,$a_mm);
    }
    redirect "/ticket/$tik_id";
};

######################################################################
# Auth rules: Copy-pastiado y simple / garlompo
post '/login' => sub {
        my ($success, $realm) = authenticate_user(
            params->{username}, params->{password}
        );
        if ($success) {
            session logged_in_user => params->{username};
            session logged_in_user_realm => $realm;
        } else {
            redirect '/login';
        }
};
    
any '/logout' => sub {
    session->destroy;
    redirect '/';
};

######################################################################
# Regla para agarrar cualquier error o guascazo cósmico.
any qr{.*} => sub {
    status 'not_found';
    template '404', { path => request->path };
}; 

=pod

=head1 Autor y Licencia.

Programado por B<Marxbro> aka B<Gstv>, distribuir solo bajo la licencia
WTFPL: I<Do What the Fuck You Want To Public License>.

Zaijian.

=cut

true;
