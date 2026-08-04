import numpy as np
import scipy.constants as const
from scipy.interpolate import interp1d
from scipy.integrate import simpson
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

#hardcoded, not good, figure out a lookup table or something for this.
thpt_files = ["/Users/incharajagadeesh/CASSI_26/MIRMOS/throughput/MIRMOS-thpt-y-codr.dat",
              "/Users/incharajagadeesh/CASSI_26/MIRMOS/throughput/MIRMOS-thpt-j-codr.dat",
              "/Users/incharajagadeesh/CASSI_26/MIRMOS/throughput/MIRMOS-thpt-h-codr.dat",
              "/Users/incharajagadeesh/CASSI_26/MIRMOS/throughput/MIRMOS-thpt-k-codr.dat"]

sky_files = ["/Users/incharajagadeesh/CASSI_26/MIRMOS/atmosphere/xtcalc_mirmos_sky_Y.dat",
             "/Users/incharajagadeesh/CASSI_26/MIRMOS/atmosphere/xtcalc_mirmos_sky_J.dat",
             "/Users/incharajagadeesh/CASSI_26/MIRMOS/atmosphere/xtcalc_mirmos_sky_H.dat",
             "/Users/incharajagadeesh/CASSI_26/MIRMOS/atmosphere/xtcalc_mirmos_sky_K.dat"]

atm_file = "/Users/incharajagadeesh/CASSI_26/MIRMOS/atmosphere/atm_trans_mirmos.dat"

dispersions = [1.478, 1.548, 2.153, 3.003] #angstroms per pixel, yjhk

band_edges = [(1.0, 1.1), (1.1, 1.4), (1.4, 1.9), (1.9, 2.4)] #yjhk, check IDL!!

def emission_line_signal(l, flux, line_width, line_centre, z):
    '''
    l is wavelength (lambda) in micron
	flux should be given in 1e-18 erg/s/cm^2
	line width should be in terms of FWHM, km/s
	centre is the peak of the Gaussian in microns (i.e, emission line at 2.1 micron)
    z is redshift
    
    returns gaussian emission line with given params and redshifted wavelengths
	'''
    wavelegnth = np.asarray(l, dtype=np.float64)
    wavelegnth *= (1+z)
    fwhm = line_centre * line_width/(const.c*1e-3)
    sigma = fwhm/(2*np.sqrt(2*np.log(2)))
    amp = flux/(sigma * np.sqrt(2*np.pi))
    exponent = np.exp(-0.5*((wavelegnth-line_centre)/sigma)**2)
    signal = amp*exponent

    return wavelegnth, signal

def parse_emission_spectrum_file_signal(file, z): #need FULL filepath
    wavelength, flux = np.loadtxt(file, comments='#', unpack=True) #wavelength is in angstroms

    wavelength *= (1+z)/10000 # in micron and also redshifted

    l_full, flux_full, thpt, sky, atm_binned = bin_signal_thp_atm_sky_data(wavelength, flux)

    return l_full, flux_full, thpt, sky, atm_binned

def calculate_AB_magnitude(l_full, flux_full, thpt): #wavelength should be in angstroms
    mAB = []
    #hooray this works
    for i in range(len(l_full)):
        l_full[i] *= 1e4
        i1 = -2.5*np.log10(simpson(flux_full[i] * thpt[i] * l_full[i],  l_full[i]) / simpson(thpt[i]/l_full[i], l_full[i]))-2.41
        mAB.append(i1)
    return mAB

def rescale_spectrum(mAB, flux_full, targ_mAB):
    scales = [10**(-0.4*(targ_mAB-m)) for m in mAB]
    flux_final = [f*s for f,s in zip(flux_full, scales)]

    return flux_final

def bin_signal_thp_atm_sky_data(l, signal):
    '''
    l is wavelength (lambda) in micron
    signal is in ergs/s/cm^2 (check with gwen/drew/william)

    the main thing about this function is that it assumes you have already redshifted lambda
    returns correctly binned wavelengths and according signal
    '''
    l_full = []
    signal_full = []
    thpt = []
    sky = []

    for (lo, hi), disp in zip(band_edges, dispersions):
        # does the (redshifted) spectrum actually cover this band?
        if l.min() <= hi and l.max() >= lo:
            lo_eff = max(lo, l.min())
            hi_eff = min(hi, l.max())
            l_full.append(np.arange(lo_eff, hi_eff, disp/10000)) #need to get disp in micron/pixel
        else:
            l_full.append(np.array([]))
        signal_full.append(interp1d(l, signal, kind="linear")(l_full[-1]))

    for i in range(len(sky_files)):
        wvl_thp, thp_dat = np.loadtxt(thpt_files[i])[:,0], np.loadtxt(thpt_files[i])[:,1]
        wvl_sky, sky_dat = np.loadtxt(sky_files[i])[:,0], np.loadtxt(sky_files[i])[:,1]

        # intersect: only keep grid points covered by BOTH throughput and sky files
        lo = max(l_full[i].min(), wvl_thp.min(), wvl_sky.min()) if len(l_full[i]) else None
        hi = min(l_full[i].max(), wvl_thp.max(), wvl_sky.max()) if len(l_full[i]) else None

        if lo is None or lo >= hi:
            l_full[i] = np.array([])
            signal_full[i] = np.array([])
            thpt.append(np.array([]))
            sky.append(np.array([]))
            continue

        mask = (l_full[i] >= lo) & (l_full[i] <= hi)
        l_full[i] = l_full[i][mask]
        signal_full[i] = signal_full[i][mask]

        thpt.append(interp1d(wvl_thp, thp_dat, kind='linear')(l_full[i]))
        sky.append(interp1d(wvl_sky, sky_dat, kind='linear')(l_full[i]))

        wavelength_atm, atm = [np.loadtxt(atm_file)[:,0], np.loadtxt(atm_file)[:,1]]
    atm_binned = []
    for i in range(len(l_full)):
        atm_binned.append(interp1d(wavelength_atm, atm, kind="linear")(l_full[i]))

    return l_full, signal_full, thpt, sky, atm_binned

def apply_thpt_atm_to_signal(l, signal, thpt, atm): #emission only
    '''
    input results from "bin_signal_thp_atm_sky_data(l, signal)"

    outputs the signal as seen by detectors
    '''
    for i in range(len(l)):
        signal[i] *= (thpt[i] * atm[i])
    return signal

def apply_thpt_to_sky(l, sky, thpt):
    '''
    input results from "bin_signal_thp_atm_sky_data(l, signal)"

    outputs the sky as seen by detectors
    '''
    for i in range(len(l)):
        sky[i] *= (thpt[i])
    return sky

def calculate_signal_to_photon_counts(l, signal, area, type = 'micron'):
    '''
    returns signal in terms of photons/pixel/second
    wavelength is in micron!
    '''
    if type=='angstrom':
        scale = 1e17
    else:
        scale = 1e13

    signal_per_pixel = []
    for i in range(len(l)):
        signal_per_pixel.append(signal[i]*area*(l[i]/(const.h * const.c* scale))*dispersions[i]*1e-4)
    return signal_per_pixel

def calculate_sky_to_photon_counts(sky, area, slit_width=0.84, angular_extent=0.84):
    sky_per_pixel = []
    for i in range(len(sky)):
        sky_per_pixel.append(sky[i]*area*angular_extent*slit_width*dispersions[i])
    return sky_per_pixel

def calculate_signal_to_noise(signal, sky, exp_time = 1000, angular_extent=0.84, rn = 21, n_reads = 16):
    n_spatial = angular_extent/0.38 #property of object --> doesn't change with lambda

    eta_read = (rn/np.sqrt(n_reads)) * np.sqrt(n_spatial) # read noise
    eta_dark = np.sqrt(n_spatial * 0.005 * exp_time) # dark current
    eta_poisson = np.sqrt(signal*exp_time)
    eta_sky = np.sqrt(sky*exp_time)

    tot_noise = np.sqrt(eta_poisson**2 + eta_sky**2 + eta_dark**2 + eta_read**2)

    snr = (signal*exp_time)/tot_noise
    
    return snr

def calculate_exposure_time(targ_snr, signal, sky, angular_extent=0.84, rn = 16, n_reads = 16): # ask about this
    #targ_snr should be given only for peak of Gaussian

    # so the equation is 0=s^2t^2 - (SNR)^2(s+beta+dark)t - (SNR)^2(read)
    # use quadratic equation --> t = [(SNR)^2(s+beta+dark) +/- sqrt(((SNR)^2(s+beta+dark))^2 + 4s^2(read)(SNR)^2)]/2s^2
    # and then only take the positive root cuz the determinant is bigger than b coeff

    n_spatial = angular_extent/0.38 #property of object --> doesn't change with lambda

    #excpet for read noise, these are all COEFFICIENTS, not noise
    eta_read = ((rn/np.sqrt(n_reads)) * np.sqrt(n_spatial))**2 
    eta_dark = n_spatial * 0.005 # dark current
    eta_poisson = signal
    eta_sky = sky

    a = eta_poisson**2
    b = -(eta_poisson+eta_sky+eta_dark)(targ_snr**2)
    c = -(eta_read)(targ_snr**2)

    exp_time = (-b + np.sqrt(b**2 - (4*a*c)))/(2*a)

    return exp_time