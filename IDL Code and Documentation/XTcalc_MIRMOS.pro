; Exposure time Calculator for the MIRMOS instrument on Magellan
; Written by Gwen C. Rudie (gwen@carnegiescience.edu)
; Based on Code written by GCR for MOSFIRE on Keck

; band: name of band
; slit_width: width of slit in arcseconds
; Nreads: number of reads in fowler
; theta: angular size of the object along the slit
; nExp: the number of exposures: if nEXP > 2, assumes a 2 point dither
; magnitude
; AB - set if the magnitude is in AB
; lineF: line flux in 10^-18 erg/s/cm^2
; lineW: line wavelength of interest (rest or observed)
; Angstroms: set to 1 if the line width is in Angstroms
; FWHM: rest-frame line FWHM in km/s
; z: redshift of line of interest
; theta: angular size of the object along the slit
; time: exposure time in seconds
; SN: desired signal to noise
; GUI: the GUI state so we can print to the GUI
; Airmass: the airmass value you want to use for the sky bkgrd
; wvcol: the water vapor column to use for the sky bkgrd
; output_struct, a structure storing the output spectra for plotting
;                and printing
;specFile, if set, this is the filename for the micron, F_nu spectrum 
;          that the user input. Integrate the value, make it match the
;          magnitude they input, and then use for the SN calculation

;UPDATES: (1)  Keck Mirror relectance updated 6/26/2012 by GCR
;         (2)  Throughput changed to the measured throughput.
;              Measurements by CCS, code by GCR 6/26/2012
;         (3)  Sky Background Spectra updated to sky spectra taken with
;              MOSFIRE. Spectra from CCS, code by GCR 6/26/2012
;              ATM transmission spectra still from Gemini
;         (4)  Read Noise takes into account the number of exposures,
;              code by GCR 6/27/2012
;         (5)  The values reported for the continuum S/N calculation
;              were changed from averages across the band to medians across
;              the band. 6/28/2012
;         (6)  Currently the S/N etc are calculated over the portion of
;              sky spectrum that is not zero-valued as opposed to being
;              over the full band pass of the filter. 
;         (7)  Changed K band spectrum out for the longer wavelength coverage
;         (8)  Fixed bug with user input wavelengths 7/2/2012 GCR
;         (9)  Fixed potential bug caused by user's setting on
;              the DEVICE, "DECOMPOSED" setting. Added 
;              DEVICE, DECOMPOSED=1 command to run_XTcalc.pro, GCR 7/2/2012
;         (10) Enabled creation of a directory to write files
;              into. Fixes write out bug. GCR 7/2/2012
;         (11) Read noise updated to 21 e-/pixel CDS. GCR 4/18/2013

;NEEDED UPDATES: (1) Current Sky Spectrum is cropped at long
;                    wavelengths in H band and on both edges of the K
;                    band

; XTcalc, 'K', 0.7, 16, lineF=9.0, lineW=6563, /Angstroms, FWHM=90, theta=0.7, z=2.3, time=1000
; XTcalc, 'K', 0.7, 16, mag=18.6, time=1000


pro XTcalc_MIRMOS, band, slit_width, Nreads, theta, nExp, mag=mag, AB=AB, $
            lineF=lineF, lineW=lineW, Angstroms=Angstroms,  $
            FWHM=FWHM, z=z, time=time, SN=SN, GUI=GUI, $
            output_struct=output_struct, specFile=specfile, specStruc=specStruc, ok=ok


  ;if the number of exposures is greater than 1, assume two dither positions
  if (nExp gt 1) then dither=2.0 else dither=1.0

  ;the location of the code and the data spectra
  usr_path=getenv('MIRMOS_XTCALC')
  bk_path=usr_path+'/atmosphere/'
  tp_path=usr_path+'/throughput/'

  ;additional margin to multiply by the
  ;throughput curves to refelct
  ;additional losses possible given the
  ;expected margins
  if not keyword_set(tp_margin) then tp_margin=0.9

  ;put everything in micron
  if (keyword_set(lineF) and keyword_set(Angstroms)) then lineW=lineW/10000.0

  ok=1

  ;***************************************************
  ;***************************************************
  ;       MOSIFRE Linearity Limits
  ;       2.15 e/ADU gain
  ;       1% non linearity 26K ADU= 55900 electrons
  ;       5% non linearity 37K ADUs = 79550 e-
  ;       saturation 43K ADUs = 92450 e-
  ;***************************************************
  ;***************************************************

  one_per_limit=55900
  five_per_limit=79550
  sat_limit=92450

  ;*************************************
  ;*************************************
  ;       MIRMOS Bands
  ;*************************************
  ;*************************************


  ;to implement dichroic bands
  ;tp of dichroics will be included elsewhere
  ;4/28/2020
  ;wavelength ranges in micron
  if (band eq 'Y') then band_range=[0.886,1.124]
  if (band eq 'J') then band_range=[1.124,1.352]
  if (band eq 'H') then band_range=[1.466,1.807]
  if (band eq 'K') then band_range=[1.921,2.404]

  if (band eq 'H') or (band eq 'K') then begin

     tmp_band_range=band_range*10
     bd_max=ceil(max(tmp_band_range))*1.0/10.+0.1
     bd_min=floor(min(tmp_band_range))*1.0/10.-0.1

  endif else begin

     tmp_band_range=band_range*100
     bd_max=ceil(max(tmp_band_range))*1.0/100.+0.1
     bd_min=floor(min(tmp_band_range))*1.0/100.-0.1

  endelse
 
  filt_wave=findgen(10001)*(bd_max-bd_min)/10000.+bd_min
  filt=fltarr(10001)
  filt[where( (filt_wave gt band_range[0]) and (filt_wave lt band_range[1]) )]=1.0


  ;check to see if the band is correct
  if keyword_set(lineW) then begin
     line=lineW*(1+z)

     if ((line gt max(filt_wave)) or (line lt min(filt_wave))) then begin
        ok=0

        if keyword_set(GUI) then begin
           longString=String(Format=$
                             '("This wavelength (",(f0.4)," micron) is not contained in ",(A)," band.")',line, band) 
           widget_control, GUI.output_text, set_value=LongString
           display_warning, LongString

        endif else print, String(Format='("This wavelength (",(f0.4)," micron) is not contained in ",(A)," band.")',line, band)
        
     endif
  endif


  ;if in Y band, check to be sure we are
  ;in a region with background sky data
  if (band eq 'Y') then begin
     if keyword_set(lineW) then begin
        line=lineW*(1+z)

        if ((line lt 0.9)) then begin
           ok=0

           if keyword_set(GUI) then begin
              longString=[String(Format=$
                             '("This wavelength (",(f0.4)," micron) currently has no background sky spectrum implemented in XTcalc.")',line)," At this time, XTcalc does not support a S/N calculation below 0.9 micron."]
              widget_control, GUI.output_text, set_value=LongString
              display_warning, LongString

           endif else print, String(Format=$
                             '("This wavelength (",(f0.4)," micron) currently has no background sky spectrum implemented in XTcalc. We therefore do not support a S/N calculation below 0.9 micron.")',line)
        
        endif
     endif
  endif





  ;*************************************
  ;*************************************
  ; check the user input spectrum
  ;*************************************
  ;*************************************

  if keyword_set(specFile)  then begin

     if (keyword_set(specStruc) eq 0) then begin

        readcol, specFile, userWave, userFlux, format='f,f', delimiter=' ,:'

     endif else begin

        userWave=specStruc.wave
        userFlux=specStruc.flux

     endelse

     if keyword_set(Angstroms) then userWave=userWave/10000.0

     userWave=userWave*(1+z)

     real_filt_wave=filt_wave(where(filt gt 0.01))

     ;does the user spectrum cover the full band pass
     ;and are the wavelengths in micron
     if ((min(userWave) gt min(real_filt_wave)) or (max(userWave) lt max(real_filt_wave))) then begin
        
        ok=0
        
        warning=['The read-in spectrum from '+specFile,$
                 'does not span the full wavelength coverage of the '+band+' band',$
                 'or is not in the proper format. The correct format is ',$
                 'observed-frame wavelength in micron or Angstroms and flux in',$
                 'erg/s/cm'+String(178B)+' in two column format with a space or comma',$
                 'as the delimiter. Also please check that you have choosen the corect',$
                 '"wavelength unit" on the GUI.']

        display_warning, warning

     endif

  endif

  if (ok ne 0) then begin

  ;if the magnitude is entered in Vega, change it to AB.
  ; conversions for J,H,Ks from Blanton et al 2005
  ; K from ccs
  ; Y from CFHT WIRCam
  if (keyword_set(mag) and (keyword_set(AB) eq 0)) then begin
     if (band eq 'Y') then mag=mag+0.66 $
     else if (band eq 'J') then mag=mag+0.91 $
     else if (band eq 'H') then mag=mag+1.39 $
     else if (band eq 'K') then mag=mag+1.95 $              
     else if (band eq 'Ks') then mag=mag+1.85                     

  endif 


  ;*************************************
  ;*************************************
  ;         CONSTANTS
  ;*************************************
  ;*************************************

  ;the speed of light in cm/s
  c=alog10(29979245800.D)

  ;planks constant in erg*s
  h=alog10(6.626068)-27

  ;in log(erg cm)
  loghc=c+h

  f_nu_AB=48.59


  ;*************************************
  ;*************************************
  ;    Magellan and IRMOS CONSTANTS
  ;*************************************
  ;*************************************

  ;area of the telescope in cm^2
  ;UPDATED FOR Magellan 5/28/2019
  ;6.5m primary with a 7% obstruction
  AT=3.14159*(6.5*100./2.0)^2*0.93
 
  ;spatial pixel scale in arcseconds/pixel
  ;FOR MIRMOS 5/28/2019
  pix_scale=0.38

  ;dispersion pixel size
  ; FOR MIRMOS 5/28/2019
  pix_disp=0.42
 
  ;Number of pixels in dispersion direction on the detector
  tot_Npix=2048.

  ;Detector readnoise in electrons/pix CDS (correlated double sampling)
  ; assume 21 (plan to test 12-21)
  if not keyword_set(det_RN) then det_RN=21.


  if keyword_set(slit_width) and not keyword_set(pix_slit_w) then  pix_slit_w=slit_width/pix_disp

  ;set the slit width in arcseconds based on the pixel slit width
  if keyword_set(pix_slit_w) and not keyword_set(slit_width) then slit_width=pix_slit_w*pix_disp


;  print, "Slit width is "+string(slit_width, format='(f5.2)')+$
;         " which is "+string(pix_slit_w, format='(f4.1)')+" pixels"



  ;*************************************
  ;*************************************
  ;         SKY CONSTANTS
  ;*************************************
  ;*************************************

  ;UPDATED 10/20/2021
  ;xtcalc_mirmos_sky_K.dat updated:
  ;Additional 0.2 magnitudes added to
  ;thermal background in K to account
  ;for ADC thermal emissivity

  ;UPDATED 4/28/2020
  ;sky spectra are modified MOSFIRE spectra
  ;additional thermal background in K
  ;blue end of Y added
  ;units are wavelength[micron] photons/cm^2/s/Angstrom/arcsec^2

  sky_spec='xtcalc_mirmos_sky_'+band+'.dat'
  readcol, bk_path+sky_spec, lam, sky , format='f,f', /silent

;  print, "Sky Bakcground File is "+bk_path+sky_spec

  ;convert to the same units as the old gemini spectrum
  ;photons/sec/arcsecond^2/nm/m^2
  ;multiply by 10^4 for per cm^2 to m^2 and 10 for per nm to A
  sky=sky*10^(4.+1.)

  zero_index=where(sky lt 0,ct_index)
  if (ct_index gt 0) then sky[zero_index]=0

  ;UPDATED 4/28/2020
  ;read in the atmospheric transparency
  transpec='atm_trans_mirmos.dat'
  readcol, bk_path+transpec, tran_lam, trans, format='f,f', /silent

;  ;the spectral resolution for 
;  ; a 2.5 pixel width slit 
;  if not keyword_set(r_pix) then r_pix=4000.
;
;  ;rtheta for a one arcsecond slit
;  ;test 2.5 pixel slit delivers R=4000 or 3200. 
;  res1=r_pix/(2.5*pix_disp)
;
;  print, "R*theta product is "+string(res1, format='(f6.1)')



  ;*************************************
  ;*************************************
  ;       IRMOS Parameters
  ;*************************************
  ;*************************************

  ;qe: quantum efficiency
  ;disp: dispersion in angstroms/pixel (UPDATED 4/28/2020)
  ;dark current in electrons per second
  ;rt: R-theta product: divide by slit width to get resolution  (UPDATED 4/28/2020)

  ;f_not: log of magnitude zero point in erg/s/cm^2/micron

  Kstat={disp:3.003, $
         lambda:2.1625, $
;         f_not:alog10(3.8)-7, $
         dark: 0.005, $
         rt:3024.0 $
          }

  Hstat={disp:2.153, $
         lambda:1.6365, $
;         f_not:alog10(1.08)-6, $
         dark: 0.005, $
         rt:3192.0 $
          }

  Jstat={disp:1.548, $
         lambda:1.238, $
;         f_not:alog10(2.90)-6, $
         dark: 0.005, $
         rt:3360.0 $
          }

  Ystat={disp:1.478, $
         lambda:1.005, $
 ;        f_not:alog10(7.45)-6, $
         dark: 0.005, $
         rt:2856.0 $
          }

  ;*************************************
  ;*************************************
  ;*************************************
  ;*************************************

 
  if (band eq 'K') then stat=Kstat else $
     if (band eq 'H') then stat=Hstat else $
        if (band eq 'J') then stat=Jstat else $
           if (band eq 'Y') then stat=Ystat 
  

  ;*************************************
  ;*************************************
  ;       IRMOS Throughput
  ;*************************************
  ;*************************************

  ;UPDATED 10/20/2021
  ;new throughput numbers including changes to the dichoic tree

  ;read in the throughput spectrum UPDATED 4/29/2020
  ;this includes: ADC, corrector, collimator, camera,
  ;dichroics,VPHG, detector, stops, telescope, (no margin, no atmosphere)
  readcol, tp_path+'MIRMOS-thpt-nomargin-'+band+'-codr.dat', tp_wave, throughput, format='f,f', /silent

  ;multiply by the specified margin
  throughput=throughput*tp_margin

  zero_index=where(throughput lt 0, zero_count)
  if (zero_count gt 0) then throughput[zero_index]=0.0

  ;real FWHM resolution
  R=stat.rt/slit_width
  
  ;slit width in pixels along the dispersion direction
  swp=slit_width/pix_disp

  ;spectral coverage (in micron)
  cov=tot_Npix*(stat.disp/10000.)


;  print, "slit width in pixels along the dispersion direction: ", swp
;  print, "resolution: ",R
 
  ;*************************************
  ;*************************************
  ;     Using a specific line flux
  ;*************************************
  ;*************************************
  if keyword_set(lineF) then begin

     ;figure out the relavant wavelength range

     ;the observed line wavelength in micron
     center=lineW*(1+z)

     ;resolution at the central wavelength in micron
     res=center/R

     ;the width of the spectral line before going through the spectrograph
     real_width=center*FWHM*10^(-c+5)
    
     ;the line width in micron that would be observed
     width=sqrt(real_width^2+res^2)


  endif else begin

     ;*************************************
     ;*************************************
     ; we are calculating for a broad band flux
     ;*************************************
     ;*************************************

     center=stat.lambda

     ;resolution at the central wavelength in micron
     res=center/R

  endelse 

  ;make the sampling of the
  ;filter curve the same as the MIRMOS sampling
  mirmos_resolution, filt_wave, filt, stat.lambda, R, stat.disp, $
                      out_wave=wave_grid, out_flux=fltSpecObs, /no_conv

  ;the relavant portion of the spectrum
  band_index=where(fltSpecObs gt 0.1)

  fltSpecObs=fltSpecObs[band_index]

  ; a tighter contraint for the S/N
  filt_index=where(fltSpecObs gt 0.5)
  
  ;convolve the atm_Transmission spectrum with the resolution
  ;make the sampling of the
  ;filter curve the same as the MIRMOS sampling
  mirmos_resolution, tran_lam, trans, stat.lambda, R, stat.disp, $
                      out_wave=wave_grid, out_flux=tranSpecObs, /no_conv

  tranSpecObs=tranSpecObs[band_index]


;fix this: may or may not need to to this, depending on if TP is per
;band or a curve.
  ;tpSpecObs=wave_grid/wave_grid*throughput

  ;convolve the throughput spectrum with the resolution
  mirmos_resolution, tp_wave, throughput, stat.lambda, R, stat.disp, $
                      out_wave=wave_grid, out_flux=tpSpecObs, /no_conv

  tpSpecObs=tpSpecObs[band_index]

  ;convolve the background spectrum with the resolution
  ;background in phot/sec/arcsec^2/nm/m^2
  mirmos_resolution, lam, sky, stat.lambda, R, stat.disp, $
                      out_wave=wave_grid, out_flux=raw_bkSpecObs, /no_conv
  zero_index=where(raw_bkSpecObs lt 0,ct_index)
  NONzero_index=where((raw_bkSpecObs ge 0) and (raw_bkSpecObs ne -0))
  if (ct_index gt 0) then raw_bkSpecObs[zero_index]=0

  raw_bkSpecObs=raw_bkSpecObs[band_index]
  wave_grid=wave_grid[band_index]



  ;for now - sent the filt_index to be
  ;the same as the [band_index]-ed NONzero_index
  filt_index=where((raw_bkSpecObs ge 0) and (raw_bkSpecObs ne -0))

  ;*************************************
  ;*************************************
  ;     Using a specific line flux
  ;*************************************
  ;*************************************
  if keyword_set(lineF) then begin

     ;the location inside the FWHM of the line
     line_index=where(abs(wave_grid - center) le 0.5*width)

     ; the area used to caluclate the S/N
     sn_index=line_index

     ;now send the background spectrum through the telescope by 
     ;multiplying the throughput, the
     ;slit_width, the angular extent (theta), the area of the
     ;telescope, and the pixel scale in nm

     ;this gives phot/sec/pixel
     bkSpecObs = raw_bkSpecObs * tpSpecObs * slit_width *theta * (AT*10.^(-4)) * (stat.disp/10.0)
;     bkSpecObs = raw_bkSpecObs * tpSpecObs * (0.5)^2* (AT*10.^(-4)) * (stat.disp/10.0)*10^(0.4*1.3)

     ;determine the average background
     ;within the FWHM of the line 

     ;this is no longer true
     ;in photons per second per pixel per Ang.

     ;in photons per second per arcsec^2 per nm per m^2
     mkBkgd=mean(sky[where(abs(lam-center) le 0.5*width)])
     
     ;fv_back=mkBkgd*(center)^2*10^(-4+3-4-c)

     ;what does this correspond to in AB mags/arcsec^2

     ;go to erg/s/cm^2/Hz
     ;10^-4 for m^2 to cm^2
     ;10^3 for micron to nm
     ;lam^2/c to covert from d(lam) to d(nu) (per Hz instead of per nm)
     ;hc/lam to convert photons to ergs
     mag_back=-2.5*(alog10(mkBkgd*center)-4+3+h)-f_nu_AB
   
  

     ; the signal in electrons per second that will hit the telsecope
     ; as it hits the atmosphere (ie need
     ; to multiply by the throughput and
     ; the atmospheric transparency
     signalATM = lineF * 10^(-18-loghc-4) * center * AT
     
                     ;don't need the FWHM part
     ;signal = lineF * 10^(-18-loghc-4) * AT * center *erf(sqrt(alog(2)))
     ; wave_grid_res=mean(wave_grid[1:n_elements(wave_grid)-1]-wave_grid[0:n_elements(wave_grid)-2])


     ;the width of the line in sigma - not FWHM
     ;in micron
     sigma=width/(2*sqrt(2*alog(2)))

     ;a spectrum version of the signal
     ;phot per second per pixel (without atm or telescope)
     ; ie total(signal_spec/signal) with
     ; equal resolution of wave_grid /
     ; stat.disp in micron
     signal_spec=signalATM*(1/(sqrt(2*!pi)*sigma))*exp(-0.5*(wave_grid-center)^2/sigma^2)*stat.disp/10.^4


     ; the spectrum of the signal as detected
     sigSpecObs=signal_spec * tpSpecObs * tranSpecObs




     ; the nubber of pixels in the spectral direction
     nPixSpec = (width*10000.0)/stat.disp

     ;the spatial pixel scale
     nPixSpatial=theta/pix_scale

     ;The number of pixels per FWHM observed
     Npix= nPixSpec * NpixSpatial

  endif else begin
     ;*************************************
     ;*************************************
     ; we are calculating for a broad band flux
     ;*************************************
     ;*************************************


     ; the area used to caluclate the S/N
     sn_index=filt_index


     mag_back=-2.5*(alog10(mean(raw_bkSpecObs[filt_index])*center)-4+3+h)-f_nu_AB


     ;now send the background spectrum through the telescope by 
     ;multiplying the throughput, the
     ;slit_width, the angular extent, the area of the
     ;telescope, and the pixel scale in nm

     ;this gives phot/sec/pixel
     bkSpecObs = raw_bkSpecObs * tpSpecObs * slit_width * theta * (AT*10.^(-4)) * (stat.disp/10.0)
;     bkSpecObs = raw_bkSpecObs * tpSpecObs * (0.5)^2 * (AT*10.^(-4)) * (stat.disp/10.0)



     ;*************************************
     ;*************************************
     ; using the user input spectrum
     ;*************************************
     ;*************************************

     if keyword_set(specFile) then begin

        ;convolve with the resolution of mirmos
        mirmos_resolution,  userWave, userFlux, stat.lambda, R, stat.disp, $
                             out_wave=user_wave_grid, out_flux=userSig
        userSig=userSig[band_index]

        ;multiply by the normalized filter
        ;transmission 

        filt_shape=fltSpecObs/max(fltSpecObs)
        userSig=userSig*filt_shape

        ;make the total match
        ;the broad band magnitude
        scale=10.0^(-0.4*(mag[0]+f_nu_AB))/mean(userSig)

        if mag[0] eq 0 then scale=1

        ;raw fv spec
        raw_fv_sig_spec=userSig*scale


        ;convert to flux hitting the primary
        ;in flux hitting the primary in
        ;phot/sec/micron 
        ;(if the earth had no atmosphere)
        ;phot/sec/micron = fnu * AT / lam / h
        signal_spec=raw_fv_sig_spec*10.^(-1*h)*AT / wave_grid


     endif else begin
     ;*************************************
     ;*************************************
     ; using a flat F_nu spec (DEFAULT)
     ;*************************************
     ;*************************************
        
         ;fv=10^((-2/5)*MagAB-48.59) (erg/s/cm^2/Hz)
         ;convert to flam: flam=fv*c/lam^2 (erg/s/cm^2/micron)
         ;covert to photons: phot/sec/micron = fnu * AT / lam / h

        ;flux hitting the primary in
        ;phot/sec/micron (if the earth had no atmosphere)
        signal_spec=10.0^(-0.4*(mag[0]+f_nu_AB)-h) * AT / wave_grid

       ; newSpec=10.0^(-0.4*(mag[0]+f_nu_AB)) * wave_grid/wave_grid

     endelse


     ;multiply by the atmospheric transparency
     signal_spec=signal_spec * tranSpecObs

     ; now put it through the throughput of the telescope
     ; phot/sec/micron
     sigSpecObs= signal_spec * tpSpecObs

     ; now for phot/sec/pix multiply by micron/pix
     sigSpecObs=sigSpecObs * (stat.disp/10000.0)

     ;number of pixels per resolution element in the 
     ;spectral direction

     nPixSpec = (res*10000.0)/stat.disp

     ;the spatial pixel scale
     nPixSpatial=theta/pix_scale

     ;The number of pixels per FWHM observed
     Npix= nPixSpec * NpixSpatial


    

     ;*************************************
     ;*************************************
     ; NEED TO ADD SLIT LOSSES FOR OBJECT
     ;*************************************
     ;*************************************


  endelse


  if keyword_set(SN) then begin


     ; differentiate between total exposure time 
     ; and amount of time of individual exposures
    
;     ; figure out how long it takes
;     qb=bkSpecObs + stat.dark*nPixSpatial + sigSpecObs
;     qa=-nPixSpec * sigSpecObs^2/SN[0]^2
;     qc=det_RN^2/Nreads*nPixSpatial

     ; figure out how long it takes

     ;if calulating with a line flux, assume S/N over the line
     ; other wise, S/N per spectral pixel
     if keyword_set(lineF) then qa=-nPixSpec * sigSpecObs^2/SN[0]^2 $
     else qa=-sigSpecObs^2/SN[0]^2

     qb=dither*bkSpecObs + dither*stat.dark*nPixSpatial + sigSpecObs
     qc=dither*det_RN^2/Nreads*nPixSpatial*nExp

     timeSpec=(-qb - sqrt( qb^2 - 4*qa*qc ))/(2*qa)
     
     time=median(timeSpec[sn_index]) 

     time=float(time)

  endif

  ; the signal to noise

  ; noise contributions
  ; poisson of background
  ; poisson of dark current
  ; poisson of the signal
  ; read noise


  ;the noise per slit length in the spatial direction
  ; and per pixel in the spectral direction

  ; the noise spectrum: 
  ; Poisson of the dark
  ; current, signal, and background + the read noise"

  noiseSpecObs = sqrt( sigSpecObs*time[0] + dither*( (bkSpecObs +stat.dark*nPixSpatial)*time[0] +$
                                                     det_RN^2/Nreads*nPixSpatial*nExp))


;  noiseSpecObs = sqrt((bkSpecObs +stat.dark*nPixSpatial + sigSpecObs)*time[0] +det_RN^2/Nreads*nPixSpatial)

  signalSpecObs =  sigSpecObs * time[0]

  snSpecObs = signalSpecObs / noiseSpecObs

  stn = mean(sqrt(nPixSpec) * snSpecObs[sn_index])

  ;the electron per pixel spectrum
  eppSpec=noiseSpecObs^2/nPixSpatial

  ;*************************************
  ;*************************************
  ;       values to be printed
  ;*************************************
  ;*************************************
  
  ;the mean instrument+telescope throughput in
  ;the same band pass
  tp = mean(tpSpecObs[sn_index])

  ;maximum electron per pixel
  max_epp=max(eppSpec[sn_index]/nExp)


  ;if calulating a line flux, S/N per FWHM 
  ;ie S/N in the line


  if keyword_set(lineF) then begin

     ;over the line (per FWHM)
     stn = mean(sqrt(nPixSpec) * snSpecObs[sn_index])

     ;signal in e/FWHM
     signal = mean(sigSpecObs[sn_index])*nPixSpec*time[0]

     ;sky background in e/sec/FWHM
     background = mean(bkSpecObs[sn_index])*nPixSpec*time[0]
 
     ;Read noise for multiple reads, electrons per FWHM
     RN=det_RN/sqrt(Nreads)*sqrt(Npix)*sqrt(nExp)

     ;noise per FWHM
     noise=mean(noiseSpecObs[sn_index])*sqrt(nPixSpec)

     ;e- 
     dark=stat.dark*Npix*time[0]


  endif else begin
     ;we are computing S/N per pixel for a continuum source

     ;per spectral pixel
     stn = median(snSpecObs[sn_index])

     ;signal in e/(spectral pixel)
     signal = median(sigSpecObs[sn_index])*time[0]

     ;sky background in e/(spectral pixel)
     background = median(bkSpecObs[sn_index])*time[0]
 
     ;Read noise for multiple reads, electrons per spectral pixel
     RN=det_RN/sqrt(Nreads)*sqrt(nPixSpatial)*sqrt(nExp)

     ;noise per spectral pixel
     noise=median(noiseSpecObs[sn_index])

     ;e- per spectral pixel
     dark=stat.dark*nPixSpatial*time[0]


  endelse

     


  ;*************************************
  ;*************************************
  ;      display the results
  ;*************************************
  ;*************************************



  if keyword_set(GUI) then begin

     struct={quant:'',value:'', unit:''}
  
     out_struct=replicate(struct,13)

     out_struct.quant=['Wavelength', 'Resolution','Dispersion', 'Throughput', 'Signal', 'Sky Background', $
                       'Sky brightness', 'Dark Current', 'Read Noise', 'Total Noise','S/N', $
                       'Total Exposure Time', 'Max e- per pixel']

     if keyword_set(lineF) then out_struct.unit=$
        ['micron','FWHM in angstrom', 'angstrom/pixel', '',  'electrons per FWHM',$
         'electrons per FWHM', 'AB mag per sq. arcsec', 'electrons per FWHM', $
         'electrons per FWHM', $
         'electrons per FWHM',$
         'per observed FWHM', 'seconds', 'electrons per pixel per exp'] $
     else out_struct.unit=$
        ['micron','angstrom', 'angstrom/pixel', '',  'electrons per spectral pixel',$
         'electrons per spectral pixel', 'AB mag per sq. arcsec', 'electrons per spectral pixel', $
         'electrons per spectral pixel', 'electrons per spectral pixel',$
         'per spectral pixel', 'seconds', 'electrons per pixel'] 

     if (max_epp ge 10.^10) then max_epp_string='>'+String(Format='(I11)',10.^10) $
     else max_epp_string=String(Format='(I10)',max_epp)

     out_struct.value=[String(Format='(f0.4)',center),String(Format='(f0.1)',res*10^4),$
                       String(Format='(f0.2)',stat.disp), String(Format='(f0.2)',tp), $
                       String(Format='(f0.2)',signal),String(Format='(f0.2)',background),$
                       String(Format='(f0.2)',mag_back),String(Format='(f0.2)',dark), $
                       String(Format='(f0.2)',RN),String(Format='(f0.2)',noise),$
                       String(Format='(f0.2)',stn),String(Format='(f0.2)',time[0]), $
                       max_epp_string]

     

     widget_control, GUI.table, set_value=out_struct
    
     ;turn the max e- per pixel red if the detector has saturated
     color_bkgrd=fltarr(3,13*3)+255
     if (max_epp gt sat_limit) then color_bkgrd[1:2,36:38]=0 else $
     if (max_epp gt five_per_limit) then begin
        color_bkgrd[2,36:38]=0 
        color_bkgrd[1,36:38]=140
        endif else $
     if (max_epp gt one_per_limit) then color_bkgrd[2,36:38]=0

     widget_control, GUI.table, BACKGROUND_COLOR=color_bkgrd

     if keyword_set(SN) then begin
        Longstring=["*****************************************",$
                    "             MIRMOS XTCalc               ",$
                    "*****************************************",$
                    String(Format='("Calculation for a signal to noise ratio of ",(f0.2))', stn),$
                    String(Format='("through a ",(f0.2)," arcsecond slit in ",(A)," band")',slit_width,band)]
     endif else begin
        Longstring=["*****************************************",$
                    "             MIRMOS XTCalc               ",$
                    "*****************************************",$
                    String(Format='("Calculation for a ",(f0.2)," second integration ")', time),$
                    String(Format='("through a ",(f0.2)," arcsecond slit in ",(A)," band")',slit_width,band)]
     endelse


     widget_control, GUI.output_text, set_value=LongString

    
 
     output_struct={wave_ptr:ptr_new(wave_grid), $
                    center:center, $
                    plot_index_ptr:ptr_new(sn_index),$
                    filt_index_ptr:ptr_new(filt_index), $
                    tp_ptr:ptr_new(tpSpecObs), $
                    filt_ptr:ptr_new(fltSpecObs), $
                    tran_ptr:ptr_new(tranSpecObs), $
                    bk_ptr:ptr_new(bkSpecObs), $
                    sig_ptr:ptr_new(sigSpecObs), $
                    signal_ptr:ptr_new(signalSpecObs), $
                    noise_ptr:ptr_new(noiseSpecObs), $
                    sn_ptr:ptr_new(snSpecObs), $
                    lineF:keyword_set(lineF), $
                    time:time[0]}
      
     ;and make a graph
    
     plot_obs, output_struct,  0, graph_window=GUI.graph 


;     plot_sn, output_struct, graph_window=GUI.graph





   endif else begin




     print, "*************************************"
     print, "*************************************"
     print, "         MIRMOS XTCalc               "
     print, "*************************************"
     print, "*************************************"
     
     print, "Calculation for a "+strtrim(string(fix(time)),1)+" second integration "
     print, "through a "+strtrim(string(slit_width),1)+" arcsecond slit in "+band+" band"
     print, ""
     
     print, "Resolution: "+strtrim(string(res*10^4),1)+" (FWHM in angstrom)"
     print, "Sampling: "+strtrim(string(stat.disp),1)+" (angstrom/pixel)"
     print, "Throughput: "+strtrim(string(tp),1)
     print, ""
     
     
     print, "Values calculated at "+strtrim(string(center),1)+" micron"
     print, "Signal: "+strtrim(string(signal),1)+" (electrons per second)"
     print, "Sky Background: "+strtrim(string(background),1)+" (electrons per second)"
     print, "Sky brightness in magnitudes: "+strtrim(string(mag_back),1)+" (AB mag/sq. arcsecond)"
     print, "Dark Current: "+strtrim(string(stat.dark),1)+" (electrons per second)"
     print, "Read Noise: "+strtrim(string(RN),1)+" (electrons)"
     print, "Time: "+strtrim(string(time),1)+" (seconds)"
     print, " "
     print, "S/N: "+strtrim(string(stn),1)+" (per resolution element)"
     
  endelse

endif


end


pro mirmos_resolution, in_wave, in_flux, center_wave, R, disp, out_wave=out_wave, $
                        out_flux=out_flux, no_conv=no_conv

 ;Number of pixels to be output - 50%
 ; more than are on the detector to
 ; cover the K band
  Npix_spec=2048.*3./2.

  ;the speed of light in cm/s
  c=alog10(29979245800.D)

  ;and the real pixel scale of mirmos
  real_wave=findgen(Npix_spec)*disp*10.^(-4.)
  real_wave=real_wave-real_wave[round(Npix_spec/2.)]   
  real_wave=real_wave+center_wave 

  ; if you don't want to convolve
  ; it, just interpolate it onto
  ; the MIRMOS pixel scale
  if keyword_set(no_conv) then begin

     ;interpolate onto the pixel scale of the detector
     out_wave=real_wave
     out_flux=interpol(in_flux, in_wave, real_wave)


  endif else begin

     ;make a "velocity" grid centered at
     ;the central wavelength of the band
     ; sampled at 1 km/s
     vel=(findgen(200001)-100000)

     in_vel=(in_wave/center_wave -1)*10.^(1*c-5)

     in_vel_short=in_vel[(where((in_vel gt vel[0]) and (in_vel lt vel[200000])))]
     in_flux_short=in_flux[(where((in_vel gt vel[0]) and (in_vel lt vel[200000])))]

     interp_flux=interpol(in_flux_short, in_vel_short, vel)

     ;sigma  = the resolution of the spectrograph
     sigma=(10.^(c-5)/R)/(2*sqrt(2*alog(2)))

     ;make a smaller velocity array with
     ;the same "resolution" as the steps in
     ;vel, above
     n = round(8*sigma)
     if n mod 2 eq 0 then n += 1
     vel_kernal=findgen(n)-floor(n/2.0)

     ;a gaussian of unit area and width sigma
     gauss_kernal=(1/(sqrt(2*!pi)*sigma))*exp(-0.5*vel_kernal^2/sigma^2)

     convol_flux=convol(interp_flux, gauss_kernal) 
     convol_wave = center_wave*(vel*10.^(-1*c+5) + 1 )

     ;interpolate onto the pixel scale of the detector
     out_wave=real_wave
     out_flux=interpol(convol_flux, convol_wave, real_wave)


  endelse



end



pro plot_obs, struct, xrange, graph_window=graph_window

  ;make the structure into something useful
  wave_grid=*struct.wave_ptr
  sn_index=*struct.plot_index_ptr
  filt_index=*struct.filt_index_ptr
  tpSpecObs=*struct.tp_ptr
  fltSpecObs=*struct.filt_ptr
  tranSpecObs=*struct.tran_ptr
  bkSpecObs=*struct.bk_ptr
  sigSpecObs=*struct.sig_Ptr
  center=struct.center
  time=struct.time
  lineF=struct.lineF
  

  if keyword_set(graph_window) then wset=graph_window

;  white = FSC_Color('white')
;  black = FSC_Color('black')
;  gray = FSC_Color('gray')
;  blue  = FSC_Color('blue')
;  red   = FSC_Color('red')
;  green = FSC_Color('green')
;  magenta = FSC_Color('magenta')
;  orange = FSC_Color('orange')
;  cyan  = FSC_Color('cyan')
;  yellow= FSC_Color('gold')
;  purple=FSC_Color('purple')

  white = 16777215
  black = 0
  gray = 12500670
  blue  = 16711680
  red   = 255
  green = 65280
  magenta = 16711935
  orange = 42495
  cyan  = 16776960
  yellow= 55295
  purple= 15736992


  

  if lineF then begin
     
     if ((n_elements(xrange) eq 1) and (xrange[0] eq 0)) then begin
        index=where(abs(wave_grid-center) lt .01)
        xrange=[floor(min(wave_grid[index]*100))/100.,ceil(max(wave_grid[index]*100))/100. ]
     endif else begin
        index=where((wave_grid lt max(xrange)) and (wave_grid gt min(xrange)))
     endelse

     
     plot, wave_grid[index], sigSpecObs[index]*time/max(sigSpecObs[index]*time), background=white, $
           color=black, /nodata, xstyle=1, ystyle=8, $
           xrange=xrange,$
           xtitle='Wavelength [micron]', font=1, thick=2, charsize=2,position=[.15,.18,.8,.95], $
           ytitle='Transmission'
     

  endif else begin
     
     if ((n_elements(xrange) eq 1) and (xrange[0] eq 0)) then begin

        index=where(fltSpecObs gt 0.5)
        xrange=[floor(min(wave_grid[index]*100))/100.,ceil(max(wave_grid[index]*100))/100. ]
     endif else begin

        index=where((wave_grid lt max(xrange)) and (wave_grid gt min(xrange)))
     endelse

     plot, wave_grid[index], fltSpecObs[index], background=white, $
           color=black, /nodata, xstyle=1, ystyle=8, $
           xrange=xrange,$
           xtitle='Wavelength [micron]', font=1, thick=2, charsize=2,position=[.15,.18,.8,.95], $
           ytitle='Transmission'
     
     
  endelse

      ;*************************************
      ;*************************************
      ; plot the atmosphere and the throughput
      ;*************************************
      ;*************************************

  ;atmospheric trasparency
  oplot, wave_grid, tranSpecObs, color=purple, thick=2

  ;throughput
  oplot, wave_grid, tpSpecObs, color=green, thick=2


  xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.8, $
          'Atmosphere', color=purple, font=1, charsize=2, alignment=1
  xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.7, $
          'Throughput', color=green, font=1, charsize=2, alignment=1


      ;*************************************
      ;*************************************
      ; plot the sky and background spec
      ;*************************************
      ;*************************************


  ;instrumentally broadened night sky lines
  oplot, wave_grid[filt_index], $
         sqrt(bkSpecObs[filt_index]*time)/(2*max(sigSpecObs[filt_index]*time)), $
         color=red, thick=2

  ;signal
  oplot, wave_grid, sigSpecObs*time/(2*max(sigSpecObs*time)), color=blue, thick=2
  
  xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.6, $
          'Sky Resid', color=red, font=1, charsize=2, alignment=1
  xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.5, $
          'Science', color=blue, font=1, charsize=2, alignment=1
  
  axis, yaxis=1, ystyle=1, yrange=!Y.CRANGE*2*max(sigSpecObs*time[0]), ytitle='photons/pixel', $
        font=1,  charsize=2, color=black


end

pro plot_sn, struct, xrange, graph_window=graph_window

  if keyword_set(graph_window) then wset=graph_window

  white = 16777215
  black = 0
  gray = 12500670
  blue  = 16711680
  red   = 255
  green = 65280
  magenta = 16711935
  orange = 42495
  cyan  = 16776960
  yellow= 55295
  purple= 15736992

  

  ;make the structure into something useful
  wave_grid=*struct.wave_ptr
  sn_index=*struct.plot_index_ptr
  noiseSpecObs=*struct.noise_ptr
  snSpecObs=*struct.sn_ptr
  filt_index=*struct.filt_index_ptr
  signalSpecObs=*struct.signal_Ptr
  center=struct.center
  time=struct.time
  fltSpecObs=*struct.filt_ptr
  lineF=struct.lineF

  if lineF then begin

     if ((n_elements(xrange) eq 1) and (xrange[0] eq 0)) then begin

        index=where(abs(wave_grid-center) lt .01)
        xrange=[floor(min(wave_grid[index]*100))/100.,ceil(max(wave_grid[index]*100))/100. ]
     endif else begin

        index=where((wave_grid lt max(xrange)) and (wave_grid gt min(xrange)))
     endelse


     plot, wave_grid[index], fltSpecObs[index], background=white, $
           color=black, /nodata, xstyle=1, ystyle=4, $
           xrange=xrange,$
           xtitle='Wavelength [micron]', font=1, thick=2, charsize=2,position=[.15,.18,.8,.95]
         

  endif else begin

    if ((n_elements(xrange) eq 1) and (xrange[0] eq 0)) then begin

        index=where(fltSpecObs gt 0.5)
        xrange=[floor(min(wave_grid[index]*100))/100.,ceil(max(wave_grid[index]*100))/100. ]
     endif else begin

        index=where((wave_grid lt max(xrange)) and (wave_grid gt min(xrange)))
     endelse
     
     plot, wave_grid[index], fltSpecObs[index], background=white, $
           color=black, /nodata, xstyle=1, ystyle=4, $
           xrange=xrange,$
           xtitle='Wavelength [micron]', font=1, thick=2, charsize=2,position=[.15,.18,.8,.95]
                
  endelse

  oplot, wave_grid[filt_index], snSpecObs[filt_index]/(1.3*max(snSpecObs)), thick=2, color=green

  xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.8, $
          'S/N', color=green, font=1, charsize=2, alignment=1


  oplot, wave_grid[filt_index], signalSpecObs[filt_index]/(2*max(signalSpecObs)), thick=2, color=blue

  xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.7, $
          'Signal', color=blue, font=1, charsize=2, alignment=1

  oplot, wave_grid[filt_index], noiseSpecObs[filt_index]/(2*max(signalSpecObs)), thick=2, color=red

   xyouts, !X.CRange[1]-0.1*(!X.CRange[1]-!X.CRange[0]), 0.6, $
          'Noise', color=red, font=1, charsize=2, alignment=1


   axis, yaxis=0, ystyle=1, yrange=!Y.CRANGE*1.3*max(snSpecObs), ytitle='S/N per pixel', $
         font=1,  charsize=2, color=black

   axis, yaxis=1, ystyle=1, yrange=!Y.CRANGE*2*max(signalSpecObs), ytitle='photons/pixel', $
         font=1,  charsize=2, color=black

end
