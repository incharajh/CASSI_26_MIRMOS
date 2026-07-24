; Exposure time Calculator for the MIRMOS instrument on Magellan
; Written by Gwen C. Rudie (gwen@carnegiescience.edu)
; Based on Code written by GCR for MOSFIRE on Keck

; run_XTcalc_MIRMOS is responsible for creating and initializing the GUI

pro run_XTcalc_MIRMOS

  ;fixes a possible bug with color output
  DEVICE, DECOMPOSED=1

  ;make the main GUI
  base=widget_base(column=2,title="XTCalc v1.2 MIRMOS:Exposure Time Calculator by Gwen C. Rudie")

  ;Widget_Control, DEFAULT_FONT='Helvetica'


  ;Widget_Control, DEFAULT_FONT='Times'

  ColIn=widget_base(base, column=1,  /align_left)

  ;************************************
  ;a place for the buttons
  ;************************************

  INbase=widget_base(ColIn, column=1, /align_center)
  button_base=widget_base(INbase, column=1, /frame, /align_center)

  ;button size
  bsize=130

  BBgo=widget_base(button_base, row=1, /frame,/grid_layout,/base_align_center)

  filters=['K','H','J','Y']

  label=WIDGET_LABEL(BBgo, value='Atmospheric Window',/align_left)
  filterBox=WIDGET_droplist(BBgo, value=filters, uvalue=filter, xsize=bsize, event_pro='comboBox_event')
  label=WIDGET_LABEL(BBgo, value='')
  
  holderBase=widget_base(button_base, column=2, /frame,/grid_layout,/base_align_left)

  inputBase=widget_base(holderBase, row=2, /grid_layout,/base_align_left)

  lab2=WIDGET_LABEL(inputBase, value='Slit Width',/align_left)
  swText=WIDGET_TEXT(inputBase, value='0.84',xsize=5, /editable, sensitive=1)
  lab2b=WIDGET_LABEL(inputBase, value='arcseconds',/align_left)

  aelab=WIDGET_LABEL(inputBase, value='Angular extent',/align_left)
  aeText=WIDGET_TEXT(inputBase, value='0.84',xsize=5, /editable, sensitive=1) 
  aelab2=WIDGET_LABEL(inputBase, value='arcseconds',/align_left)

  inputBase=widget_base(holderBase, row=2, /grid_layout,/base_align_left)

  lab2=WIDGET_LABEL(inputBase, value='Number of Exp.',/align_left)
  neText=WIDGET_TEXT(inputBase, value='2',xsize=5, /editable, sensitive=1)
  lab2b=WIDGET_LABEL(inputBase, value='',/align_left)

  lab3=WIDGET_LABEL(inputBase, value='Fowler Sampling',/align_left)
  fsText=WIDGET_TEXT(inputBase, value='16',xsize=5, /editable, sensitive=1)
  lab3b=WIDGET_LABEL(inputBase, value='paired reads',/align_left)


  ;************************************
  ;type of input
  ;************************************

   inputBase2=widget_base(button_base, row=4, /frame);,/grid_layout,/base_align_center)
   lab1=WIDGET_LABEL(inputBase2, value='Input a line flux or broad-band magnitude:')


   button_base2=widget_base(inputBase2, row=1, /frame, /exclusive)
   line_button=widget_button(button_base2, value='Use Line Flux', uvalue='line', /no_release, $
                             event_pro='line_flux_button_press')
   Mag_button=widget_button(button_base2, value='Use Magnitude', uvalue='mag', /no_release, $
                            event_pro='line_flux_button_press')


  ;************************************
  ;line flux input
  ;************************************

   lineFluxBase=widget_base(inputbase2, row=4,/frame,/grid_layout,/base_align_center)

   lfLab=WIDGET_LABEL(lineFluxBase, value='Line Flux',/align_left)
   lfText=WIDGET_TEXT(lineFluxBase, value='9.0',xsize=8, /editable, sensitive=1)

  ;string=textoidl('10$^{-18}$ erg/s/cm')
   string='1E-18 erg/s/cm'
  
   lfLab2=WIDGET_LABEL(lineFluxBase, value=string+String(178B),/align_left)


   cwlab=WIDGET_LABEL(lineFluxBase, value='Central Wavelength',/align_left)
   cwText=WIDGET_TEXT(lineFluxBase, value='5007.',xsize=8, /editable, sensitive=1)
   button_base2=widget_base(lineFluxBase, row=1, /frame, /exclusive)
   A_button=widget_button(button_base2, value='Angstroms', uvalue='A', /no_release, event_pro='A_button_press')
   m_button=widget_button(button_base2, value='Microns', uvalue='micron', /no_release, event_pro='A_button_press')


   zlab=WIDGET_LABEL(lineFluxBase, value='Redshift',/align_left)
   zText=WIDGET_TEXT(lineFluxBase, value='2.3',xsize=8, /editable, sensitive=1) 
   zlab2=WIDGET_LABEL(lineFluxBase, value='',/align_left)

   fwhmLab=WIDGET_LABEL(lineFluxBase, value='Source FWHM',/align_left)
   FWHMText=WIDGET_TEXT(lineFluxBase, value='100.',xsize=8, /editable, sensitive=1) 
   fwhmLab2=WIDGET_LABEL(lineFluxBase, value='km/s',/align_left)

;   aelab=WIDGET_LABEL(lineFluxBase, value='Angular extent (along slit)',/align_left)
;   aeText=WIDGET_TEXT(lineFluxBase, value='0.7',xsize=8, /editable, sensitive=1) 
;   aelab2=WIDGET_LABEL(lineFluxBase, value='arcsecond',/align_left)

  
  ;************************************
  ;magnitude input
  ;************************************
 


   magInputBase=widget_base(inputbase2, row=3, /frame,/align_center)

   line1base=widget_base(magInputBase, row=1)

   magBase=widget_base(line1Base, row=1)
   magLab=WIDGET_LABEL(magBase, value='Magnitude  ',/align_left)
   magText=WIDGET_TEXT(magBase, value='18.6',xsize=8, /editable)

   button_base2=widget_base(magBase, row=1, /frame, /exclusive)
   ABbutt=widget_button(button_base2, value='AB', uvalue='AB', /no_release, event_pro='AB_button_press')
   Vbutt=widget_button(button_base2, value='Vega', uvalue='Vega', /no_release, event_pro='AB_button_press')


   specInputBase=widget_base(line1Base, row=1)

   specLab=WIDGET_LABEL(specInputBase, value='  Type of Spectrum',/align_right)
 
   ;Spectrum type choices
   specChoice=['Flat F_nu', 'My Own Spectrum']
   specBox=WIDGET_droplist(specInputBase, value=specChoice, $
                             uvalue=specChoice, xsize=bsize, event_pro='specType_Choice_event')
  junkLab=WIDGET_LABEL(specInputBase, value='',/align_left)


   mySpecBase=widget_base(magInputBase, column=1)

   fileNameBase=widget_base(mySpecBase, row=1)

   fileNameLab=WIDGET_LABEL(fileNameBase, value='Filename',/align_left)

   specNameText=WIDGET_TEXT(fileNameBase, value='',xsize=40, /all_events, event_pro='specNameText_event')

   fileTypeLab=WIDGET_LABEL(fileNameBase, value='ASCII: (lam f_nu)',/align_left)

   otherBase=widget_base(mySpecBase, row=1, /grid_layout)

   waveBigBase=widget_base(otherBase, row=1)
   lamLab=WIDGET_LABEL(waveBigBase, value='wavelength unit ',/align_left)
   waveBase=widget_base(waveBigBase, row=1, /exclusive, /frame)
   Amag_button=widget_button(waveBase, value='Angstroms', uvalue='A', /no_release, event_pro='Amag_button_press')
   mmag_button=widget_button(waveBase, value='Microns', uvalue='micron', /no_release, event_pro='Amag_button_press')

   zbase=widget_base(otherBase, row=1, /grid_layout)
   zlab=WIDGET_LABEL(zbase, value='   Redshift',/align_left)
   zMagText=WIDGET_TEXT(zbase, value='0.0',xsize=8, /editable, sensitive=1) 
   





   col2_base=widget_base(INbase, column=1, /align_left)



  ;************************************
  ;choose what to calculate
  ;************************************
   
   bb_optional=widget_base(col2_Base, row=3, /frame,/base_align_center)
   lab1=WIDGET_LABEL(bb_optional, value='Input an exposure time or a desired signal to noise ratio:')

 
   button_base2=widget_base(bb_optional, row=1, /frame, /exclusive,/base_align_center)
   ET_button=widget_button(button_base2, value='Determine Exposure Time', uvalue='et', /no_release,$
                           event_pro='SN_button_press')
   SigNo_button=widget_button(button_base2, value='Determine Signal to Noise', uvalue='sn', /no_release,$
                           event_pro='SN_button_press')


  ;************************************
  ;exposure time
  ;************************************
   choicebase=widget_base(bb_optional, row=1, /base_align_center)


   etbb=widget_base(choicebase, row=1, /frame, /base_align_center)
   etLab1=WIDGET_LABEL(etbb, value='Total Exposure Time',/align_left)
   etText=WIDGET_TEXT(etbb, value='1000',xsize=8, /editable, sensitive=1)
   etLab2=WIDGET_LABEL(etbb, value='seconds',/align_left)



  ;************************************
  ;signal to noise
  ;************************************



   snbb=widget_base(choicebase, row=1, /frame, /grid_layout,/base_align_center)
   snLab=WIDGET_LABEL(snbb, value='Desired S/N',/align_left)
   snText=WIDGET_TEXT(snbb, value='10',xsize=8, /editable)

   
;  ;************************************
;  ;airmass and water vapor
;  ;************************************
;
;
;   skyBase=widget_base(col2_Base, row=4, /frame) 
;   lab1=WIDGET_LABEL(skyBase, value='Optional Input: Airmass and Water Vapor')
;
;
;   button_base2=widget_base(skyBase, row=1, /frame, /exclusive)
;   def_button=widget_button(button_base2, value='Use Default', uvalue='default', /no_release, $
;                             event_pro='am_wv_button_press')
;   user_button=widget_button(button_base2, value='Input Airmass and Water Vapor Column', uvalue='user', /no_release, $
;                            event_pro='am_wv_button_press')
;
;   optionBase=widget_base(skyBase, row=1)
;   amBase=widget_base(optionBase, row=2,/frame,/grid_layout,/base_align_center)
;   amlab=WIDGET_LABEL(amBase, value='Airmass',/align_center)
;   amBBase=widget_base(amBase, row=1, /frame, /exclusive)
;   am1_button=widget_button(amBBase, value='1.0', uvalue='10', /no_release, $
;                             event_pro='airmass_button_press')
;   am15_button=widget_button(amBBase, value='1.5', uvalue='15', /no_release, $
;                             event_pro='airmass_button_press')
;   am2_button=widget_button(amBBase, value='2.0', uvalue='20', /no_release, $
;                             event_pro='airmass_button_press')
;  
;   wvBase=widget_base(optionBase, row=2,/frame,/grid_layout,/base_align_center)
;   wvlab=WIDGET_LABEL(wvBase, value='Water Vapor (mm)',/align_center)
;   wvBBase=widget_base(wvBase, row=1, /frame, /exclusive)
;   wv1_button=widget_button(wvBBase, value='1.0', uvalue='10', /no_release, $
;                             event_pro='wv_button_press')
;   wv16_button=widget_button(wvBBase, value='1.6', uvalue='16', /no_release, $
;                             event_pro='wv_button_press')
;   wv3_button=widget_button(wvBBase, value='3.0', uvalue='30', /no_release, $
;                             event_pro='wv_button_press')
;   wv5_button=widget_button(wvBBase, value='5.0', uvalue='50', /no_release, $
;                             event_pro='wv_button_press')
   
   
  ;************************************
  ;action buttons
  ;************************************



   bbb=widget_base(ColIn, row=1, /frame,/grid_layout, /base_align_center)
;   lab7b=WIDGET_LABEL(bbb, value='')
   lab7b=WIDGET_LABEL(bbb, value='')
   go_button = widget_button(bbb, value="Calculate", event_pro='calc_button_event', xsize=bsize, /align_center)
   exit_button = widget_button(bbb, value="Exit", event_pro='exit_button_event', xsize=bsize, /align_center)
;   lab7b=WIDGET_LABEL(bbb, value='')
   lab7b=WIDGET_LABEL(bbb, value='')


  ;************************************

  ;************************************
  ;OUTPUT
  ;************************************


  output_base=widget_base(base,column=1, frame=1 )

  ;************************************
  ;text output
  ;************************************


  output_text=Widget_text(output_base, value='',ysize=5,xsize=50)

  ;************************************
  ;table output
  ;************************************

  struct={quant:'',value:'', unit:''}
  
  out_struct=replicate(struct,13)

    
  table=widget_table(output_base, value=out_struct, column_widths=[140,100,180],$
                    /no_column_headers, /no_row_headers)           

  ;************************************
  ;graphical output
  ;************************************


  graph_base=widget_base(output_base,column=1, frame=1 )


  usr_size=100

  plotOptionBase=widget_base(graph_base, row=1, /frame, /exclusive,/base_align_center)
  plotObs_button=widget_button(plotOptionBase, value='Plot Observations', uvalue='obs', /no_release,$
                          event_pro='plot_button_press')
  plotSN_button=widget_button(plotOptionBase, value='Plot Signal to Noise', uvalue='sn', /no_release,$
                          event_pro='plot_button_press')


  plotWaveBase=widget_base(graph_base, row=1,/base_align_left, /frame)

  lab2=WIDGET_LABEL(plotWaveBase, value='Plot Wavelengths', /align_left)

  plotWaveOptionBase=widget_base(plotWaveBase, row=1, /frame, /exclusive,/base_align_center)
  defaultWave_button=widget_button(plotWaveOptionBase, value='Default', uvalue='def_wave', /no_release,$
                          event_pro='userWave_button_press')
  userWave_button=widget_button(plotWaveOptionBase, value='User Specified', uvalue='usr_wave', /no_release,$
                          event_pro='userWave_button_press')



  WaveBase=widget_base(plotWaveBase, row=1,/base_align_left, /frame)
  
  startWave=WIDGET_TEXT(WaveBase, value='2.100',xsize=5, /editable, sensitive=1, $
                        event_pro='textWave_edit_event')
  
  lab2=WIDGET_LABEL(WaveBase, value='--',/align_left)

;  lab2=WIDGET_LABEL(plotWaveBase, value='End Wave',/align_left)
  endWave=WIDGET_TEXT(WaveBase, value='2.300',xsize=5, /editable, sensitive=1, $
                      event_pro='textWave_edit_event')
  lab2b=WIDGET_LABEL(WaveBase, value='micron',/align_left)



  ;make a graph window for the absorption plots that gets mouse click events
  graph=widget_draw(graph_base, xsize=4.5*usr_size, ysize=3.25*usr_size)

  writeBase=widget_base(graph_Base, row=1, /frame, /base_align_center)
  
  write_button = widget_button(writeBase, value="Write to File", event_pro='write_button_event', $
                               xsize=bsize)
  specOutBase=widget_base(writeBase, row=2, /base_align_center, /grid_layout, /NONEXCLUSIVE)
  tp_button=widget_button(specOutBase, value='Throughput', uvalue='tp', /no_release, $
                             event_pro='write_button_select')
  tran_button=widget_button(specOutBase, value='Transmission', uvalue='tran', /no_release, $
                             event_pro='write_button_select')
  bk_button=widget_button(specOutBase, value='Background', uvalue='bk', /no_release, $
                             event_pro='write_button_select')
  sig_button=widget_button(specOutBase, value='Signal', uvalue='sig', /no_release, $
                             event_pro='write_button_select')
  noise_button=widget_button(specOutBase, value='Noise', uvalue='noise', /no_release, $
                             event_pro='write_button_select')
  sn_button=widget_button(specOutBase, value='S/N', uvalue='sn', /no_release, $
                             event_pro='write_button_select')



  ;make the GUI appear on screen
  widget_control, base, /realize

  ;get the index for the draw window
  widget_control, graph, get_value=graph_val


;  Widget_Control, DEFAULT_FONT='Times'

  ; set the default pressed radio buttons
  widget_control, A_button, Set_button=1
  widget_control, mmag_button, Set_button=1
  ;widget_control, ABbutt, Set_button=1
  widget_control, Vbutt, Set_button=1
  ;widget_control, ET_button, Set_button=1
  widget_control, SigNo_button, Set_button=1
  widget_control, defaultWave_button, Set_button=1
  widget_control, line_button,Set_button=1 
;  widget_control, def_button,Set_button=1
;  widget_control, wv16_button,Set_button=1 
;  widget_control, am1_button,Set_button=1 
  widget_control, plotObs_button, Set_button=1

  ;set the filter drop box to "H"
  widget_control, filterBox, set_droplist_select=where(filters eq 'H')

  ;set which input buttons are active
  widget_control, lineFluxBase, sensitive=1
  widget_control, magInputBase, sensitive=0
  widget_control, etbb, sensitive=1
  widget_control, snbb, sensitive=0
;  widget_control, optionBase, sensitive=0
  widget_control, plotOptionBase, sensitive=0
  widget_control, plotWaveBase, sensitive=0
  widget_control, writeBase, sensitive=0
  widget_control, mySpecBase, sensitive=0



  out_struct={wave_ptr:ptr_new(), $
              center:0.0, $
              plot_index_ptr:ptr_new(),$
              filt_index_ptr:ptr_new(),$
              tp_ptr:ptr_new(), $
              filt_ptr:ptr_new(), $
              tran_ptr:ptr_new(), $
              bk_ptr:ptr_new(), $
              sig_ptr:ptr_new(), $
              signal_ptr:ptr_new(), $
              noise_ptr:ptr_new(), $
              sn_ptr:ptr_new(), $
              lineF:0, $
              time:0.0}


  ;make a state structure to store state variables
  state={filterBox:filterBox, $           ;pass the name of the filterBox widget
         swText:swText, $                 ;name of the slit width box
         neText:neText, $                 ;name of the number of exposures box
         fsText:fsText, $                 ;name of the fowler sampling box
         lineFluxBase:lineFluxBase, $     ; name of the base for line Flux input
         magInputBase:magInputBase, $     ;name of the base for magnitude input
         mySpecBase:mySpecBase, $     ; name of base where you input the spec filename
         expTimeBase:etbb, $              ; name of the exposre time base
         SNBase:snbb, $                   ;name of the signal to noise base
         ;amWVBase:optionBase, $            ;name of the airmass, water vapor base
         plotOptionBase:plotOptionBase, $ ;name of the base with the plotting options
         plotWaveBase:plotWaveBase, $
         waveBase:waveBase, $
         writeBase:writeBase, $           ; name of the base for writting output 
         lfText:lfText, $                 ;name of the line flux box
         cwText:cwText, $                 ;name of the central wavelength box
;         A_button:A_button, $             ;name of the angstrom button
;         m_button:m_button, $             ;name of the micron button
         zText: zText, $                  ;name of the redshift box
         FWHMText:FWHMtext, $             ;name of the FWHM box
         aeText: aeText, $                ;name of the angular extent box
         magText:magText, $               ;name of the magnitude box
;         ABbutt:ABbutt, $                 ;name of the AB button
;         VButt:Vbutt, $                   ; name of vega button
         specBox:specBox, $               ; the drop list with the choices for type of spectrum
         specChoice:specChoice, $         ; the options for the specBox
         specNameText:specNameText, $      ; text box to hold the file name
         zMagText:zMagText, $             ; test box that holds the redshift desired for the spectrum
         useUserSpec:0, $                 ; set to 1 if user is inputting their own spec
         specFileName:'', $               ;file name of the user spectrum to read in
         specFilePath:'', $
         initPath:'', $
         etText:etText, $                 ;name of the expusre time box
         snText:snText, $                 ;name of the signal to noise box
         output_text:output_text, $       ;name of the output text box
         table:table, $                   ;name of the output table
         graph:graph_val, $               ;name of the output graph
         graphReady:0, $                  ; have we calculated something to graph
         plotObs:1, $                     ; are we plotting the observations or the S/N
         plotObs_Button:plotObs_Button, $
         plotSN_button:plotSN_button, $
         defWave:1, $
         defaultWave_button:defaultWave_button, $
         userWave_button:userWave_button, $
         startWave:startWave, $
         endWave:endWave,$
;         am1_button:am1_button, $         ;names of airmass buttons          
;         am15_button:am15_button, $                   
;         am2_button:am2_button, $                   
;         wv1_button: wv1_button, $        ;names of water vapor buttons           
;         wv16_button:wv16_button, $                   
;         wv3_button:wv3_button , $                   
;         wv5_button:wv5_button , $           
;         write_button:write_button, $
         tp_button:tp_button, $
         tran_button:tran_button, $
         bk_button:bk_button, $
         sig_button:sig_button, $
         noise_button:noise_button, $
         sn_button:sn_button, $
         ang:1, $                         ; the center wavelength is in Angstroms
         AB:0, $                          ; the magnitude is in AB units
         micron:1, $                      ; the input user spec is in micron
         useLineFlux: 1, $                ; Are we using the line flux of the magnitude for the calculation
         detET:0, $                       ; Are we determining the exposure time
;         user_wv_am:0, $                  ; user will input the water vapor and airmass
;         wv:'30', $                       ; string label for the water vapor column; updated 5/28/2019
;         am:'10', $                       ; string label for the airmass
;         def_am:'10', $                   ;default airmass
;         def_wv:'30', $                   ;default water vapor; updated 5/28/2019
;         def_am_button:am1_button, $      ; button for default airmass value
;         def_wv_button:wv16_button, $     ; button for dafualt water vapor
         filters:filters, $                ;the array of the names of filters
         out_prefix:'', $
         out_struct:out_struct $
         }


  if (getenv('MIRMOS_WD') eq '') then state.initPath=getenv('MIRMOS_XTCALC') $
  else state.initPath=getenv('MIRMOS_WD')

  ;get the index for the draw window
;  widget_control, graph, get_value=graph_val


  ;make a pointer to the state variable
  ;and name that uvalue of the base GUI
  state_ptr=ptr_new(state)
  widget_control, base, set_uvalue=state_ptr


  ;plot the graph
;  graph_voigts, state.vel, state.flux, *state.ptr_contam_voigt, state.trans_index, *state.ptr_params, $
;                *state.ptr_location, *state.ptr_number, state.graph_val, state.vmax

 
  xmanager, 'events_XTcalc', base, cleanup='XTcalc_close_down'





end
