#############################################################################
# Makefile for building: PCBSD
#############################################################################

####### Install

all:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh all
image:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso
iso:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso
vm:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh vm
world:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh world
jail:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh jail
check-ports:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh check-ports
ports:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports
iso-ports:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso-ports
ports-update-all:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports-update-all
ports-update-pcbsd:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports-update-pcbsd
pbi-index:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh pbi-index
clean:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh clean
menu:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh menu
