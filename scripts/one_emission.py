import numpy as np
import matplotlib.pyplot as plt
from scipy.integrate import quad
from scipy.interpolate import interp1d
import scipy.constants as const

# the first order of business is to make a singular emission line.

def create_emission(x, flux, line_width, line_centre): # this works!
	'''
	flux should be given in 1e-18 erg/s/cm^2
	line width should be in terms of FWHM, km/s
	centre is the peak of the Gaussian in microns (i.e, emission line at 2.1 micron)
	'''
	x = np.asarray(x, dtype=np.float64)
	fwhm = line_centre * line_width/(const.c*1e-3)
	sigma = fwhm/(2*np.sqrt(2*np.log(2)))
	amp = flux/(sigma * np.sqrt(2*np.pi))
	exponent = np.exp(-0.5*((x-line_centre)/sigma)**2)
	eqn = amp*exponent

	return eqn

# next, need to evaluate the gaussian on a fine grid, and then use dispersion factor to interpolate thpt data
def get_basis_thpt(flux, fwhm_km, centre):
	'''
	emission params should be in the order of flux, line_width, line_centre. the units and stuff are in the "create_emission" function
	'''

	# getting data files, prob a better way to do this idk
	if((0.95 <= centre) & (centre <= 1.1)): # y band
		thpt_file = "../throughput/MIRMOS-thpt-y-codr.dat"
		sky_file = "../atmosphere/xtcalc_mirmos_sky_Y.dat"
	elif((1.1 <= centre) & (centre <= 1.4)): # j band
		thpt_file = "../throughput/MIRMOS-thpt-j-codr.dat"
		sky_file = "../atmosphere/xtcalc_mirmos_sky_J.dat"
	elif((1.5 <= centre) & (centre <= 1.8)): # h band
		thpt_file = "../throughput/MIRMOS-thpt-h-codr.dat"
		sky_file = "../atmosphere/xtcalc_mirmos_sky_H.dat"
	elif((2 <= centre) & (centre <= 2.4)): # k band
		thpt_file = "../throughput/MIRMOS-thpt-k-codr.dat"
		sky_file = "../atmosphere/xtcalc_mirmos_sky_K.dat"
	else:
		print("Invalid centre frequency")

	atm_file = "../atmosphere/atm_trans_mirmos.dat"

	# grabbing data from the files
	thpt_data = np.loadtxt(thpt_file)
	l = np.array(thpt_data[:,0])
	thpt = np.array(thpt_data[:,1])

	dispersion = 3.003e-4 #micron per pixel
	l_fine = np.arange(centre-0.01, centre+0.01, dispersion) # array starting at f-0.01 ending at f+0.01 with dispersion as spacing
	print(len(l_fine))
	thpt_fine = interp1d(l, thpt, kind = 'linear')(l_fine) # interpolated thpt to plot
	emission = create_emission(l_fine, flux, fwhm_km, centre)
	
	sky_data = np.loadtxt(sky_file)
	l_sky = np.array(sky_data[:,0])
	sky = np.array(sky_data[:,1])

	sky_fine = interp1d(l_sky, sky, kind = 'linear')(l_fine)

	atm_data = np.loadtxt(atm_file)
	l_atm = np.array(atm_data[:,0])
	atm = np.array(atm_data[:,1])

	atm_fine = interp1d(l_atm, atm, kind = 'linear')(l_fine)

	return l_fine, emission, thpt_fine, sky_fine, atm_fine

# the plot has transmission on one axis and photons/pixel on the other.
area = 0.93 /4* np.pi*650**2
arcsec_dec = 0.84
arcsec_ra = 0.8
dispersion = 3 #angstrom per pixel
exp_time = 1000

flux = 9.0e-18
line_width = 100
line_centre = 2.1

l, emission, thpt, sky, atm = get_basis_thpt(flux, line_width, line_centre)

sky_photons_per_pixel = sky * arcsec_dec * arcsec_ra * (area) * (dispersion) #* exp_time #wat the heck bruh

emission_photons_per_pixel = emission * area * (l/(const.h * 1e7 * const.c*1e6)) * 3*1e-4 #*exp_time # this is good

emission_photons_per_pixel = thpt * emission_photons_per_pixel * atm
sky_photons_per_pixel =  thpt*sky_photons_per_pixel

plt.plot(l, emission_photons_per_pixel)
plt.show()

fig, ax = plt.subplots()

ax2 = ax.twinx()
ax.plot(l, emission_photons_per_pixel * exp_time, color = 'b', label = 'science')
ax.plot(l, np.sqrt(sky_photons_per_pixel * exp_time), color = 'r', label = 'sky residuals')

sky_photons_per_pixel /= 1

ax2.plot(l, thpt, color = 'g', label = 'throughput')
ax2.plot(l, atm, color = 'purple', label = 'atmosphere')

ax.set_xlabel('Wavelength (micron)', fontsize = 18)
ax.set_ylabel('Photons/Pixel', fontsize = 18)
ax2.set_ylabel('Transmission', fontsize = 18)

ax.set_ylim(0, 700)
ax2.set_ylim(0,1)

lines1, labels1 = ax.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax.legend(lines1 + lines2, labels1 + labels2, fontsize = 18)

ax.set_title("Exposure time of 1000 s", fontsize = 20)

ax.tick_params(axis='both', labelsize=15)
ax2.tick_params(axis='both', labelsize=15)

plt.tight_layout()
plt.show()

# --------------- SNR calculation
rn = 21 #electrons per pixel
n_reads = 16
n_spatial = arcsec_ra/0.38 #property of object --> doesn't change with lambda

print(n_spatial)

eta_read = (rn/np.sqrt(n_reads)) * np.sqrt(n_spatial) # read noise
eta_dark = np.sqrt(n_spatial * 0.005 * exp_time) # dark current
eta_tot = np.sqrt((emission_photons_per_pixel*exp_time )+ (sky_photons_per_pixel*exp_time) + (eta_dark)**2 + (eta_read)**2)

snr = emission_photons_per_pixel*exp_time/eta_tot

print(snr)

plt.plot(l, snr)
plt.xlabel("Wavelength (micron)", fontsize = 18)
plt.ylabel("SNR", fontsize = 18)
plt.title("SNR per pixel vs wavelength", fontsize = 20)
plt.xticks(fontsize=16)
plt.yticks(fontsize=16)
plt.show()