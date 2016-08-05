#!/bin/bash
######################################################################
# Usar para iniciar tiquete
######################################################################

[ $1 ] && OPCION="$1"
[ ! $1 ] && OPCION="default"

PUERTO=3456

case "$OPCION" in 

    start)
        nohup plackup -E production -p $PUERTO bin/app.psgi &> /dev/null &
    ;;

    stop)
        pkill --full plackup
    ;;

    dev)
        nohup plackup -p $PUERTO bin/app.psgi &> /dev/null &
    ;;

    default)
        echo "Por defecto se cierran todas las instancias de plackup y se ejecuta el entorno de desarrollo."
        pkill --full plackup
        nohup plackup -p $PUERTO bin/app.psgi &> /dev/null &
    ;;
    *)
        echo "Uso: [start|stop|dev]. Sin opciones ejecuta el entorno de desarrollo."
    ;;
esac



echo "Listo" &&
exit 0
