PROJECT=pci_top

PRJCLEAN=*.prj *.scr
XSTCLEAN=xlnx_auto_* *.lso *.ngc *.xrpt *.srp xst _xmsgs usage_statistics_webtalk.html webtalk.log
NGDCLEAN=*.lst *.bld *.ngd
MAPCLEAN=*.ncd *.map *.mrp *.ngm *.pcf *.xml
PARCLEAN=*.ncd *.pad *.csv *.txt *.par *.ptwx *.unroutes *.xpi
TRCCLEAN=*.twr *.twx
BITCLEAN=*.bgn *.bit *.drc *.xwbt

syn: $(PROJECT).twr $(PROJECT).bit

#############################################################################
# Xilinx Synthesis using XST
#############################################################################

$(PROJECT).prj: ../source/*.v*
	rm -f $(PROJECT).prj
	find ../source -name "*.vhd" -printf "vhdl work \"%p\"\n" >>$(PROJECT).prj
	find ../source -name "*.v" -printf "verilog work \"%p\"\n" >>$(PROJECT).prj

$(PROJECT).scr: ../$(PROJECT).scr
	cat ../$(PROJECT).scr | sed 's/#PROJECT#/$(PROJECT)/g' > $(PROJECT).scr

$(PROJECT).ngc: $(PROJECT).prj $(PROJECT).scr
	xst -ifn $(PROJECT).scr

$(PROJECT).ngd: $(PROJECT).ngc
	ngdbuild -uc ../$(PROJECT).ucf $(PROJECT).ngc

$(PROJECT).ncd: $(PROJECT).ngd
	map $(PROJECT).ngd

$(PROJECT)-routed.ncd: $(PROJECT).ncd
	par -ol high -w $(PROJECT).ncd $(PROJECT)-routed.ncd

$(PROJECT).twr: $(PROJECT)-routed.ncd
	trce -v 10 -o $(PROJECT).twr $(PROJECT)-routed.ncd $(PROJECT).pcf

$(PROJECT).bit: $(PROJECT)-routed.ncd
	bitgen -w $(PROJECT)-routed.ncd $(PROJECT).bit -f ../$(PROJECT).ut

upload: $(PROJECT).bit
	xc3sprog -c usbblast $(PROJECT).bit

flash: $(PROJECT).bit
	xc3sprog $(PROJECT).bit 1

clean: 
	rm -Rf $(PRJCLEAN) $(XSTCLEAN) $(NGDCLEAN) $(MAPCLEAN) $(PARCLEAN) $(TRCCLEAN) $(BITCLEAN)

