#Makefile for prepping a new jenkins node
#############################################################################

####### Prep

jenkins:
	@cd ${.CURDIR}/prepnode/ && sh mknode.sh

