#############################################################################
# Makefile for building: FreeNAS
#############################################################################

####### Install

all:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh all
image:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso
iso:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh iso
api:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh api
docs:
	@cd ${.CURDIR}/scripts/ && sh build-iso.sh doc
