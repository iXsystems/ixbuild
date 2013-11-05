#############################################################################
# Makefile for building: PCBSD
#############################################################################

####### Install

all:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh all
iso:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso
world:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh world
clean:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh clean
