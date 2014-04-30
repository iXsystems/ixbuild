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
check-ports:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh check-ports
ports:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports
ports-meta-only:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh ports-meta-only
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
