# Tiquete

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

El estado y la devoluciçon so potestad del admin.


# Deply bb


```bash
plackup -p 3000 bin/app.psgi
```
