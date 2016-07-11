# Tiquete

```perl
# |    o               |         
# |--- .,---..   .,---.|--- ,---.
# |    ||   ||   ||---'|    |---'
# `---'``---|`---'`---'`---'`---'
#           |                    
# ------------------------------->>
```
Proyecto de Ticket-system en Dancer2, con csv, mails y la mar en coche.

# Data estructure

* 0     ID
* 1     mail
* 2     nombre
* 3     dominio
* 4     importancia
* 5     descripcion
* --6   fecha
* ++7   estado
* ++8   devolucion

La fecha es automática.

El estado y la devolución so potestad del admin.

## La perra...

Aparentemente necesita un chillón de módulos para funkar...

```bash
cpanp i Dancer2 Session::Token Crypt::SaltedHash Dancer2::Plugin::Auth::Extensible File::Slurp Data::Uniqid Email::MIME
```

# Deploy

Por ahora usando plackup como middleware.

```bash
plackup -p 3000 bin/app.psgi
```

# Faltaría

* Deploy con mailing (no pude probar nada hasta ahora)
* ~~~Agregarle un mecanismo de login menos improvisado! (mediante `cpanp i Dancer2::Plugin::Auth::Extensible`).~~~
* Deploy and optimize (los hooks son bastante chiottos).
* Reemplazar el smartmatch (?)
* Plackup Deploy
