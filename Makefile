#############################################################################
# Makefile for building: PCBSD
#############################################################################

####### Install

all:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh all
image:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso
world:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh world
ports:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports
ports-update-all:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports-update-all
ports-update-pcbsd:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports-update-pcbsd
clean:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh clean
menu:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh menu
