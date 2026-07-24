; Exposure time Calculator for the MOSFIRE instrument on Keck I
; Written by Gwen C. Rudie (gwen@astro.caltech.edu)


;EDIT: June 4, 2018: LINE 865 CHANGED: dir_exists replaced with file_test

;checks to be sure the string input into the GUI
;can be converted to a float
;if not, displays a warning and returns ok=0
;if int set, converts to an int
pro check_num_input, input, label, min=min, max=max, ok=ok, NUMinput=NUMinput,  int=int

  ok=1
  
  catch, theError
  If theError NE 0 then begin
     catch, /cancel
     bad_io:error_set, label, ok=ok, input=input
  endif

  ;set up the I/O error handler to take in type conversion errors
  ON_IOerror, bad_io

  if (keyword_set(int) eq 0) then NUMinput=float(input)$
  else NUMinput=fix(input)


  ;check to see if the value is within the specified range
  if (ok eq 1) then begin
     if (keyword_set(min) and keyword_set(max)) then begin

     ;both min and max are set
        if ((Numinput lt min) or (NUMinput gt max)) then begin
           ok=0
           if keyword_set(int) then rangeString=$
              String(Format='("Please input a number between ",(I)," and ",(I),".")',$
                     min,max)  $
           else  rangeString=$
              String(Format='("Please input a number between ",(f0.2)," and ",(f0.2),".")',$
                     min,max)
           warning=['Your input in the '+label+' field is out of range.', $
                    rangeString]
           display_warning, warning
        endif
     endif else begin
     ;only min is set
        if keyword_set(min) then begin
           if (Numinput lt min) then begin
              ok=0
              if keyword_set(int) then rangeString=$
                 String(Format='("Please input a number greater than ",(I),".")',$
                        min)  $
              else  rangeString=$
                 String(Format='("Please input a number greater than ",(f0.2),".")',$
                        min)
              warning=['Your input in the '+label+' field is out of range.', $
                       rangeString]
              display_warning, warning
              
           endif
           
        endif else begin
        ;only max is set
           if keyword_set(max) then begin
              if (Numinput gt max) then begin
                 ok=0
                 if keyword_set(int) then rangeString=$
                    String(Format='("Please input a number less than ",(I),".")',$
                           max)  $
                 else  rangeString=$
                    String(Format='("Please input a number less than ",(f0.2),".")',$
                           max)
                 warning=['Your input in the '+label+' field is out of range.', $
                          rangeString]
                 display_warning, warning

              endif
           endif
        endelse
     endelse
  endif

end

pro error_set, label, ok=ok, input=input

     warning='Your input in the '+label+' field is not a number.'
     display_warning, warning
     ok=0
     input=0

end

pro calc_button_event, event

  ;get the state
  XT_gui_get_state, event, state

  ;set the wavelengths to the default
  state.defWave=1

  ;get the input slit width and fowler sampling
  num=widget_info(state.filterBox, /droplist_select)

  filter=state.filters[num]

  widget_control, state.swText , get_value=str_slitWidth
  widget_control, state.fsText , get_value=str_fowlerSampling
  widget_control, state.aeText , get_value=str_angularExtent
  widget_control, state.neText , get_value=str_numberOfExp
  

  check_num_input, str_slitWidth[0], 'Slit Width', ok=ok, NUMinput=slitWidth,$
                   min=0.4, max=4.0
  if (ok eq 1) then begin
     check_num_input, str_fowlerSampling[0], 'Fowler Sampling', ok=ok, $
                      NUMinput=fowlerSampling, /int, min=1
     if (ok eq 1) then begin
        check_num_input, str_angularExtent[0], 'Angular Extent', ok=ok, $
                      NUMinput=angularExtent,  min=0.1
        
        if (ok eq 1) then $
           check_num_input, str_numberOfExp[0], 'Number of Exposures', ok=ok, $
                            NUMinput=nExp, /int, min=1
     endif
  endif


  

;  slitWidth=float(str_slitWidth[0])
;  fowlerSampling=float(str_fowlerSampling[0])
  

  if (ok eq 1) then begin

  ; if we are calculating the exposure time,
  ;get the desired signal to noise
  ; otherwise get the time and we'll calculate the S/N
     if (state.detET eq 1) then begin
        widget_control, state.snText , get_value=str_SN
        check_num_input, str_SN[0], 'Signal to Noise', ok=ok, NUMinput=SN, min=0.01
     ;SN=float(str_SN)
     endif else begin
        widget_control, state.etText , get_value=str_expTime
        if (ok eq 1) then check_num_input, str_expTime[0], $
                                           'Exposure Time', ok=ok, NUMinput=expTime, min=1
                                ;expTime=float(str_expTime)
     endelse
  endif


  if (ok eq 1) then begin

  ; if we are doing the calculation with line flux
     if (state.useLineFlux eq 1) then begin
     ;get all of the line flux parameters
        widget_control, state.lfText , get_value=str_lineFlux
        check_num_input, str_lineFlux[0], 'Line Flux', ok=ok, NUMinput=lineFlux, min=.01
                                ;lineFlux=float(str_lineFlux[0])
        widget_control, state.cwText , get_value=str_wave
        if (ok eq 1) then check_num_input, str_wave[0], $
                                           'Wavelength', ok=ok, NUMinput=wave, min=0.1, max=24000
                                ;wave=float(str_wave[0])
        widget_control, state.zText , get_value=str_z
        if (ok eq 1) then check_num_input, str_z[0], 'Redshift', ok=ok, NUMinput=z, min=0
                                ;z=float(str_z[0])
        widget_control, state.FWHMText , get_value=str_FWHM
        if (ok eq 1) then check_num_input, str_FWHM[0], 'FWHM', ok=ok, NUMinput=FWHM, min=1
                                ;FWHM=float(str_FWHM[0])
;        widget_control, state.aeText , get_value=str_angularExtent
;        if (ok eq 1) then check_num_input, str_angularExtent[0], 'Angular Extent', $
;                         ok=ok, NUMinput=angularExtent, min=.1
                                

        if (ok eq 1) then begin
           if (state.detET eq 1) then $
              XTcalc_MIRMOS, filter, slitWidth, fowlerSampling, angularExtent, nExp, lineF=lineFlux, $
                             lineW=wave, Angstroms=state.ang, FWHM=FWHM, z=z, $
                             SN=SN, GUI=state,  $
                             output_struct=output_struct, ok=ok $
           else XTcalc_MIRMOS, filter, slitWidth, fowlerSampling, angularExtent, nExp,lineF=lineFlux, $
                               lineW=wave, Angstroms=state.ang, FWHM=FWHM, z=z,  $
                               time=expTime, GUI=state, $
                               output_struct=output_struct, ok=ok
        endif

     endif else begin
     ;we are doing the calculation with magnitude
     ; get all the magnitude parameters
        widget_control, state.magText , get_value=str_magnitude
        if (ok eq 1) then check_num_input, str_magnitude[0], $
                                           'Magnitude', ok=ok, NUMinput=mag, min=0, max=35
     ;mag=float(str_magnitude)

        if (ok eq 1) then begin
     ;we are using the user input spectrum
           if (state.useUserSpec eq 1) then begin
        
              readcol, state.specFileName, uWave, uFlux, format='f,f', delimiter=' ,:', $
                       count=nlines, /silent

              if (nlines eq 0) then begin

                 ok=0

                 warning=['The input file: '+state.specFileName+' is not in the correct format.', $
                          'The correct format is observed-frame wavelength in micron or angstroms and flux in',$
                          'erg/s/cm'+String(178B)+' in two column format with a space or comma',$
                          'as the delimiter.']

                 display_warning, warning 

              endif else begin

                 spec={wave:uWave, flux:uFlux}

                 widget_control, state.zMagText , get_value=str_z
                 if (ok eq 1) then begin
                    check_num_input, str_z[0], 'Redshift', ok=ok, NUMinput=z, min=0

                    if (state.micron eq 0) then Angstroms=1 else Angstroms=0
                    if (state.detET eq 1) then $
                       XTcalc_MIRMOS, filter, slitWidth, fowlerSampling, angularExtent, nExp, mag=mag, AB=state.AB,  $
                                      SN=SN, GUI=state, $
                                      output_struct=output_struct,specFile=state.specFileName,$
                                      specStruc=spec ,z=z, Angstroms=Angstroms, ok=ok $
                    else XTcalc_MIRMOS, filter, slitWidth, fowlerSampling, angularExtent, nExp, mag=mag, AB=state.AB, $
                                        time=expTime, GUI=state,  $
                                        output_struct=output_struct,specFile=state.specFileName, $
                                        specStruc=spec,z=z, Angstroms=Angstroms, ok=ok
                 endif

              endelse
           endif else begin

        ;use the default flat F_nu spec
              if (state.detET eq 1) then $
                 XTcalc_MIRMOS, filter, slitWidth, fowlerSampling, angularExtent, nExp, mag=mag, AB=state.AB,  $
                                SN=SN, GUI=state,  $
                                output_struct=output_struct, ok=ok $
              else XTcalc_MIRMOS, filter, slitWidth, fowlerSampling, angularExtent, nExp, mag=mag, AB=state.AB,  $
                                  time=expTime, GUI=state,  $
                                  output_struct=output_struct, ok=ok

           endelse

        endif



     endelse

     if (ok eq 1) then begin

        state.out_struct=output_struct
        state.graphReady=1
        state.plotObs=1

        ;update the state
        XT_gui_set_state, event, state

        ;change what the GUI shows
        update_GUI, state

     endif

  endif


end




;handles the pressing on the "Use Line Flux" and "Use Magnitude" buttons
pro line_flux_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  ;change the state of the contam boolean
  if (button eq 'line') then state.useLineFlux=1 else state.useLineFlux=0

  ;update the state
  XT_gui_set_state, event, state

  ;change what the GUI shows
  update_GUI, state

end


;handles the pressing on the "use Default" and the "input
;Airmass and Water Vapor Column" buttons
pro am_wv_button_press, event
 ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  
  if (button eq 'default') then begin
     state.user_wv_am=0 
     state.wv=state.def_wv
     state.am=state.def_am

     widget_control, state.def_am_button, set_button=1
     widget_control, state.def_wv_button, set_button=1

     endif else state.user_wv_am=1

  ;update the state
  XT_gui_set_state, event, state

  ;change what the GUI shows
  update_GUI, state

 end

; handles the airmass radio buttons
pro airmass_button_press, event
 ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  state.am=button

  ;update the state
  XT_gui_set_state, event, state

  ;change what the GUI shows
  update_GUI, state

 end

; handles the water vapor column radio buttons
pro wv_button_press, event
 ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  state.wv=button

  ;update the state
  XT_gui_set_state, event, state

  ;change what the GUI shows
  update_GUI, state

 end


;handles the pressing on the "Determine Exposure Time" and
;"Determine Signal to Noise" buttons
pro SN_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  ;change the state of the contam boolean
  if (button eq 'et') then state.detET=1 else state.detET=0

  ;update the state
  XT_gui_set_state, event, state

  ;change what the GUI shows
  update_GUI, state


end



;handles the pressing on the "Plot Observations" and
;"Plot Signal to Noise" buttons
pro plot_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  get_plot_wave, state, xrange=xrange, ok=ok

  if ok then begin
     ;change the state of the contam boolean
     if (button eq 'obs') then begin
     
        plot_obs, state.out_struct, xrange, graph_window=state.graph
        state.plotObs=1
     endif else begin

        plot_sn, state.out_struct, xrange, graph_window=state.graph
        state.plotObs=0 
     endelse

     ;update the state
     XT_gui_set_state, event, state

     ;change what the GUI shows
     update_GUI, state

  endif

end

pro get_plot_wave, state, xrange=xrange, ok=ok

  wave_grid=*state.out_struct.wave_ptr

  if (state.defWave eq 1) then begin
     xrange=0
     ok=1

  endif else begin

     widget_control, state.startWave , get_value=str_startwave
     check_num_input, str_startwave[0], 'Start Wavelength', ok=ok, NUMinput=start_wave, $
                      min=min(wave_grid) , max=max(wave_grid)

     if (ok) then begin
        widget_control, state.endWave , get_value=str_endwave
        check_num_input, str_endwave[0], 'End Wavelength', ok=ok, NUMinput=end_wave, $
                         min=min(wave_grid) , max=max(wave_grid)

        if (ok) then xrange=[start_wave, end_wave]
        if (start_wave eq end_wave) then begin
           xrange[0]=xrange[0]-0.001
           xrange[1]=xrange[1]+0.001           
        endif
     endif
  endelse

end


;handles the changing of text in the
;place where the user specified wavelengths
;are input
pro textWave_edit_event, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  get_plot_wave, state, xrange=xrange, ok=ok

  if ok then begin

     if (state.plotObs eq 1) then $
        plot_obs, state.out_struct, xrange, graph_window=state.graph $
     else plot_sn, state.out_struct, xrange, graph_window=state.graph

     ;update the state
     XT_gui_set_state, event, state

     ;change what the GUI shows
     update_GUI, state

  endif

end


;handles the pressing on the "Default" and
;"User Specified" buttons for controling the wavelengths
; of the plots
pro userWave_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  ;change the state of the contam boolean
  if (button eq 'def_wave') then begin
     state.defWave=1
  endif else begin
     state.defWave=0 

     ;figure out which wavelengths to propose using
     wave=*state.out_struct.wave_ptr
     index=*state.out_struct.plot_index_ptr

     widget_control, state.startWave, set_value=string(format='(f5.3)', min(wave[index])+0.01)
     widget_control, state.endWave, set_value=string(format='(f5.3)', max(wave[index])-0.01)
  endelse

  get_plot_wave, state, xrange=xrange, ok=ok

  if ok then begin

     if (state.plotObs eq 1) then $
        plot_obs, state.out_struct, xrange, graph_window=state.graph $
     else plot_sn, state.out_struct, xrange, graph_window=state.graph

     ;update the state
     XT_gui_set_state, event, state

     ;change what the GUI shows
     update_GUI, state

  endif

end



;handles the pressing on the "Angstrom" and
;"Micron" buttons
pro A_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  ;change the state of the contam boolean
  if (button eq 'A') then state.ang=1 else state.ang=0

  ;update the state
  XT_gui_set_state, event, state

end

;handles the pressing on the "Angstrom" and
;"Micron" buttons
pro Amag_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  ;change the state of the contam boolean
  if (button eq 'A') then state.micron=0 else state.micron=1

  ;update the state
  XT_gui_set_state, event, state

end



;handles the pressing on the "AB" and
;"Vega" buttons
pro AB_button_press, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  ;change the state of the contam boolean
  if (button eq 'AB') then state.AB=1 else state.AB=0

  ;update the state
  XT_gui_set_state, event, state


end

;used to activate and de-activate different regions of the GUI
pro update_GUI, state

  ;if we are determining the exposure
  ;time, then the ET blank should be inactive
  if (state.detET eq 1) then begin

     widget_control, state.expTimeBase, sensitive=0
     widget_control, state.SNBase, sensitive=1

  endif else begin
     ;if we are determining the signal to noise,
     ; the S/N blank should be inactive
     widget_control, state.expTimeBase, sensitive=1
     widget_control, state.SNBase, sensitive=0

  endelse

  ;if we are calculating with a line flux
  if (state.useLineFlux eq 1) then begin

     widget_control, state.lineFluxBase, sensitive=1
     widget_control, state.magInputBase, sensitive=0

  endif else begin
     ;if we are using a magnitude

     widget_control, state.lineFluxBase, sensitive=0
     widget_control, state.magInputBase, sensitive=1

  endelse


;  if (state.user_wv_am eq 1) then begin
;     widget_control, state.amWVBase, sensitive=1
;  endif else begin
;     widget_control, state.amWVBase, sensitive=0
;  endelse


  if (state.graphReady eq 1) then begin
       widget_control, state.plotOptionBase, sensitive=1
       widget_control, state.plotWaveBase, sensitive=1
       widget_control, state.writeBase, sensitive=1
  endif else begin
       widget_control, state.plotOptionBase, sensitive=0
       widget_control, state.plotWaveBase, sensitive=0
       widget_control, state.writeBase, sensitive=0

  endelse


  if (state.plotObs eq 1) then begin
     widget_control, state.plotObs_button, Set_button=1
  endif else begin
     widget_control, state.plotSN_button, Set_button=1
  endelse

  if (state.defWave eq 1) then begin
     widget_control, state.defaultWave_button, Set_button=1
     widget_control, state.waveBase, sensitive=0
  endif else begin
     widget_control, state.userWave_button, Set_button=1
     widget_control, state.waveBase, sensitive=1
  endelse


end


pro display_warning, warning, long=long


  ;figure out the size of widget you need in pixels

  strsize=fltarr(n_elements(warning),2)

  tlb = Widget_Base()

  for i=0, n_elements(warning)-1 do strsize[i,*] = $
     Widget_Info(tlb,STRING_SIZE=warning[i])

  Widget_Control, tlb, /Destroy


  xsize=max([300,strsize[*,0]])
  ysize=max([total(strsize[*,1])*2,100])


  ;figure out where to put the GUI
  device, get_screen_size=screen_size
  xoffset=screen_size[0]/4
  yoffset=screen_size[1]/4

  ;make the main GUI
  warning_base=widget_base(column=1,title="Error",xoffset=xoffset, $
                           yoffset=yoffset, frame=1, xsize=xsize, ysize=ysize)


  warning_label=widget_label(warning_base, value='')
  for i=0, n_elements(warning)-1 do begin

     warning_label=widget_label(warning_base, value=warning[i])
  endfor
  warning_label=widget_label(warning_base, value='')

  ;make the GUI appear on screen
  widget_control, warning_base, /realize

  xmanager, 'display_warning', warning_base

end






;handles a press of the exit button
pro exit_button_event, event

  ;get the state
  XT_gui_get_state, event, state


  ;close the GUI
  widget_control, event.top, /destroy



end



;when the GUI is closed
pro XTcalc_close_down, id

  widget_control, id, /destroy

end


;retrieves the state variables
pro XT_gui_get_state, event, XT_state

  ;get the pointer for the GUI state
  widget_control, event.top, get_uvalue=state_pointer

  ;check the pointer
  if (ptr_valid(state_pointer) eq 0) then print, $
     'State information pointer is not valid.'

  XT_state=*state_pointer


end


;sets the state variables
pro XT_gui_set_state, event, XT_state

  ;get the pointer for the GUI state
  widget_control, event.top, get_uvalue=state_pointer

  *state_pointer=XT_state


end

pro file_prefix_GUI_button_event, event

  ;get the state
  XT_gui_get_state, event, prefix_state

  ;figure out which button was pressed
  widget_control, event.id, get_uvalue=button

  if (button eq 'prefix') then begin

     widget_control, prefix_state.prefix_text_box, get_value=new_string

     prefix_state.prefix_text=new_string


  endif

  ;set the state
  XT_gui_set_state, event, prefix_state

  widget_control, event.top, /destroy

end

;make a GUI to get a file_prefix
pro get_file_prefix, main_state, write_event, prefix=prefix

  ;figure out where to put the GUI
  device, get_screen_size=screen_size
  xoffset=screen_size[0]/6
  yoffset=screen_size[1]/3

  ;make the main GUI
  new_base=widget_base(column=1,title="Input a file prefix",$
                       xoffset=xoffset, yoffset=yoffset, $
                       tlb_frame_attr=1, /modal, group_leader=write_event.top)

  ; a base for user input
  text_base=widget_base(new_base, row=1, /grid_layout)
  label1=widget_label(text_base, value='File Prefix')
  prefix_text=widget_text(text_base, value='', /editable, xsize=xsize)
  label1=widget_label(text_base, value='_(type)_XTcalc.txt')

  ;spacer
  label1=widget_label(new_base, value='')

  ;base for the buttons
  button_base=widget_base(new_base, row=1, /grid_layout, /align_center)

  default_button=widget_button(button_base, value="   Use My Input   ", $
                               uvalue="prefix", $
                               event_pro='file_prefix_GUI_button_event', $
                               xsize=bsize)
  

  default_button=widget_button(button_base, value="   Use Default   ", $
                               uvalue="default", $
                               event_pro='file_prefix_GUI_button_event', $
                               xsize=bsize)
  

  prefix_state={prefix_text_box:prefix_text, $
                write_event:write_event, $
                prefix_text:''}


  widget_control, new_base, /realize

  ;make a pointer to the state variable
  ;and name that uvalue of the base GUI
  prefix_state_ptr=ptr_new(prefix_state)
  widget_control, new_base, set_uvalue=prefix_state_ptr

  xmanager, 'get_file_prefix', new_base, cleanup='prefix_close'

  ; now that the gui returned, get the new state
  new_state=*prefix_state_ptr
  ;save the user input
  prefix=new_state.prefix_text

 end


;to be called if the dialogue box is closed without hitting close
pro prefix_close, id

  ;close the gui
  widget_control, id, /destroy

end


;handles the "Write to File" button press
;prints to file those spectra that are selected
pro write_button_event, event

  ;retrieve the current state
  XT_gui_get_state, event, state

  tp = widget_info(state.tp_button,/button_set)
  tran = widget_info(state.tran_button,/button_set)
  bk = widget_info(state.bk_button,/button_set)
  sig = widget_info(state.sig_button,/button_set)
  noise = widget_info(state.noise_button,/button_set)
  sn = widget_info(state.sn_button,/button_set)

  yes=tp+tran+bk+sig+noise+sn

  if (yes gt 0) then begin
     ;there is something selected so write them to file

     extention='_XTcalc.txt'

     ;first figure out where to write them to.
     out_path=dialog_pickfile(/Directory, /write, path=state.initPath)

     if (out_path ne '') then begin
;        out_path_exists = dir_exist(out_path)
        out_path_exists = FILE_TEST(out_path, /DIRECTORY)
        if (out_path_exists eq 0) then FILE_MKDIR, out_path


     ;find out if they'd like to use a file prefix
        get_file_prefix, state, event, prefix=prefix

        if (prefix ne '') then prefix=prefix+'_'

        wave=*state.out_struct.wave_ptr

     ;print throughput
        if (tp gt 0) then begin
           filename=out_path+prefix+'throughput'+extention   
           header='Wavelength (micron)  Fractional Throughput'
           print, "Printing "+filename
           write_file, wave, *state.out_struct.tp_ptr, filename, hdr=header
        endif

     ;print atmospheric transmission
        if (tran gt 0) then begin
           filename=out_path+prefix+'atm_transmission'+extention 
           header='Wavelength (micron)  Fractional Transmission'
           print, "Printing "+filename
           write_file, wave, *state.out_struct.tran_ptr, filename, hdr=header
        endif

     ;print background
        if (bk gt 0) then begin
           filename=out_path+prefix+'sky_background'+extention 
           header='Wavelength (micron)  Background (photon/sec/pixel)'
           print, "Printing "+filename
           write_file, wave, *state.out_struct.bk_ptr, filename, hdr=header
        endif

     ;print signal
        if (sig gt 0) then begin
           filename=out_path+prefix+'signal'+extention   
           header='Wavelength (micron)  Signal (photon/sec/pixel)'
           print, "Printing "+filename
           write_file, wave, *state.out_struct.sig_ptr, filename, hdr=header
        endif

     ;print noise
        if (noise gt 0) then begin
           filename=out_path+prefix+'noise'+extention  
           header='Wavelength (micron)  Noise (photon/spectral_pixel)'
           print, "Printing "+filename
           write_file, wave, *state.out_struct.noise_ptr, filename, hdr=header
        endif

     ;print signal to noise
        if (sn gt 0) then begin
           filename=out_path+prefix+'signal_to_noise'+extention
           header='Wavelength (micron)  Signal to noise per (spectral) pixel'
           print, "Printing "+filename
           write_file, wave, *state.out_struct.sn_ptr, filename, hdr=header
        endif

     endif
  endif else begin
     ;then nothing was selected
     ; print a warning
     display_warning, 'You must select which spectrum(a) to write to file.', /long
  endelse

  ;update the state
  XT_gui_set_state, event, state


end

pro write_file, wave, flux, filename, hdr=hdr

  w=transpose(wave)
  f=transpose(flux)
  out=[w,f]

  openw, outfile, filename, /get_lun

  if keyword_set(hdr) then printf, outfile, hdr

  printf, outfile, out

  close, outfile
  

end


pro specType_Choice_event, event

  ;get the state
  XT_gui_get_state, event, state

  ;figure out which type of spectrum they choose
  num=widget_info(state.specBox, /droplist_select)
  specType=state.specChoice[num]

  if (specType eq 'Flat F_nu') then begin

     state.useUserSpec = 0
     widget_control, state.mySpecBase, sensitive=0

  endif else begin
     if (specType eq 'My Own Spectrum') then begin
        state.useUserSpec = 1       
        widget_control, state.mySpecBase, sensitive=1

        ;find out the name of the file and put it in the box
        chooseFileName, event, state=state
        


     endif
  endelse


  ;update the state
  XT_gui_set_state, event, state

  ;change what the GUI shows
  update_GUI, state



end

;used to choose the file name for the
;spec to be read in
;updates the file name displayed in the box
pro chooseFileName, event, state=state


  if (state.specFileName ne '') then begin

     file=DIALOG_PICKFILE(/MUST_EXIST, /READ, Title=$
                          'Choose the ASCII (lam F_nu) spectrum for the calculation',$
                          file=state.specFileName, path=state.specFilePath,$
                          get_path=filepath)

  endif else begin
     file=DIALOG_PICKFILE(/MUST_EXIST, /READ, Title=$
                          'Choose the ASCII (lam F_nu) spectrum for the calculation',$
                          path=state.initPath,$
                          get_path=filepath)

  endelse


  ;if they cancel, then use the default
  if (file eq '') then begin
     state.useUserSpec = 0
     widget_control, state.fileNameBase, sensitive=0
     widget_control, state.specBox, set_droplist_select=0
     widget_control, state.specNameText, set_value=''
     state.specFileName=''
     state.specFilePath=''

     ;otherwise get the filename and print in in the text box
  endif else begin
     widget_control, state.specNameText, set_value=file
     state.specFileName=file
     state.specFilePath=filepath

  endelse


end


pro specNameText_event, event


  ;get the state
  XT_gui_get_state, event, state

  chooseFileName, event, state=state


  ;update the state
  XT_gui_set_state, event, state

end




pro comboBox_event, event

  ;do nothing
end

pro write_button_select, event
  ;do nothing

end


