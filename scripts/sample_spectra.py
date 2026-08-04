import numpy as np
import matplotlib.pyplot as plt
from scipy.interpolate import interp1d
import scipy.constants as const
from scipy.integrate import quad
from scipy.integrate import simpson

#hardcoded, not good, figure out a lookup table or something for this.
thpt_files = ["../throughput/MIRMOS-thpt-y-codr.dat",
              "../throughput/MIRMOS-thpt-j-codr.dat",
              "../throughput/MIRMOS-thpt-h-codr.dat",
              "../throughput/MIRMOS-thpt-k-codr.dat"]

sky_files = ["../atmosphere/xtcalc_mirmos_sky_Y.dat",
             "../atmosphere/xtcalc_mirmos_sky_J.dat",
             "../atmosphere/xtcalc_mirmos_sky_H.dat",
             "../atmosphere/xtcalc_mirmos_sky_K.dat"]

dispersions = [1.478/10000, 1.548/10000, 2.153/10000, 3.003/10000] #micron per pixel, yjhk

atm_file = "../atmosphere/atm_trans_mirmos.dat"

wavelength, flux = np.loadtxt('../ssp_1.4Gyr_z02.spec', comments='#', unpack=True) #wavelength is in angstroms

#wavelength, flux = np.loadtxt('../vega.dat', comments='#', unpack=True) #wavelength is in angstroms

wavelength /= 10000 #and now it is in microns :]
#flux *= 10000 #claude told me to do this but idk

# before doing all the next steps and binning, need to account for this extra redshift
z = 1.3# i think user is supposed to input this
targ_mag = 21 # i think user is also supposed to input this
wavelength *= (1+z)
#flux /= (1+z)

#now, need to rebin the data according to the dispersion.
band_edges = [(0.886,1.124), (1.124,1.352), (1.466,1.807), (1.921,2.404)]  # yjhk, microns

l_full = []
flux_full = []
for (lo, hi), disp in zip(band_edges, dispersions):
    # does the (redshifted) spectrum actually cover this band?
    if wavelength.min() <= hi and wavelength.max() >= lo:
        lo_eff = max(lo, wavelength.min())
        hi_eff = min(hi, wavelength.max())
        l_full.append(np.arange(lo_eff, hi_eff, disp))
    else:
        l_full.append(np.array([]))
    flux_full.append(interp1d(wavelength, flux, kind="linear")(l_full[-1]))

print(len(l_full))
print(len(flux_full))

#now, to do the same for throughput, sky, atm data
thpt = []
sky = []
wavelength_full = []

for i in range(len(sky_files)):
    wvl_thp, thp_dat = np.loadtxt(thpt_files[i])[:,0], np.loadtxt(thpt_files[i])[:,1]
    wvl_sky, sky_dat = np.loadtxt(sky_files[i])[:,0], np.loadtxt(sky_files[i])[:,1]

    # intersect: only keep grid points covered by BOTH throughput and sky files
    lo = max(l_full[i].min(), wvl_thp.min(), wvl_sky.min()) if len(l_full[i]) else None
    hi = min(l_full[i].max(), wvl_thp.max(), wvl_sky.max()) if len(l_full[i]) else None

    if lo is None or lo >= hi:
        l_full[i] = np.array([])
        flux_full[i] = np.array([])
        thpt.append(np.array([]))
        sky.append(np.array([]))
        continue

    mask = (l_full[i] >= lo) & (l_full[i] <= hi)
    l_full[i] = l_full[i][mask]
    flux_full[i] = flux_full[i][mask]

    thpt.append(interp1d(wvl_thp, thp_dat, kind='linear')(l_full[i]))
    sky.append(interp1d(wvl_sky, sky_dat, kind='linear')(l_full[i]))
    wavelength_full.extend(l_full[i])

wavelength_atm, atm = [np.loadtxt(atm_file)[:,0], np.loadtxt(atm_file)[:,1]]
atm_binned = []
for i in range(len(l_full)):
    atm_binned.append(interp1d(wavelength_atm, atm, kind="linear")(l_full[i]))

#so now i have flux, throuput, sky, atm all according to the relevant dispersions.
#the next thing is to do the integral to get mAB and then use the user inputted mAB to get photon counts per pixel per second

mAB = []
#hooray this works
for i in range(len(l_full)):
    l_full[i] *= 1e4
    i1 = -2.5*np.log10(simpson(flux_full[i] * thpt[i] * l_full[i],  l_full[i]) / simpson(thpt[i]/l_full[i], l_full[i]))-2.41
    mAB.append(i1)

#frac = [x/y for x, y in zip(num, den)]

#mAB = [-2.5*np.log10(i) for i in integral] #Jy

print(mAB)

scales = [10**(-0.4*(targ_mag-m)) for m in mAB]

#flux_final = [f * 1e-23 * ((l**2)/(const.c*1e6)) * scale for f,l in zip(flux_full, l_full)]
flux_final = [f*s for f,s in zip(flux_full, scales)]

#OK so now i have the corrected flux and can turn it into photon counts

area = 0.93 /4* np.pi*650**2
slit_width = 0.84
angular_extent = 0.84 #idk what to use for this

dispersions = [d*10000 for d in dispersions] #back in angstroms
#print(dispersions)

sky_photons_per_pixel = []
for i in range(len(dispersions)):
    val = [s* t *1000*dispersions[i] * slit_width * angular_extent * area for s, t in zip(sky[i], thpt[i])]
    # val = [v if v >= 0 else 0 for v in val]
    sky_photons_per_pixel.append(np.sqrt(val))

# sky counts are good!

flux_photons_per_pixel = []
for i in range(len(dispersions)):
    flux_loop = flux_final[i]
    #flux_loop = [3631*f*(const.c*1e6)/(l**2) for f, l in zip(flux_final[i], l_full[i])] #now this is f_nu in Jy
    
    # erg/cm^2/s/A * cm^2 * A/pixel * s==> erg/pixel
    tot_E = [(f)*(area)*(dispersions[i])*1000 for f in flux_loop]

    # photon energy in ergs
    photon_E = [(l)/(const.h*const.c*1e17) for l in l_full[i]]

    #this should be p
    val = [t*p for t, p in zip(tot_E, photon_E)]
    val = [v*a*t for v, a, t in zip(val, atm_binned[i], thpt[i])]
    flux_photons_per_pixel.append(val)

#ok so now i think everything is in photon counts

l_cont = []
f_cont = []
s_cont = []
thpt_cont = []
atm_cont = []
l_full = [l/10000 for l in l_full]
for i in range(len(dispersions)):
    l_cont.extend(l_full[i])
    f_cont.extend(flux_photons_per_pixel[i])
    s_cont.extend(sky_photons_per_pixel[i])
    thpt_cont.extend(thpt[i])
    atm_cont.extend(atm_binned[i])

# plt.plot(l_cont, s_cont, label = "sky residuals")
# plt.plot(l_cont, f_cont, label = "science")
# plt.ylabel("photons/pixel/second")
# plt.xlabel("micron")
# plt.legend()
# plt.show()

fig, ax = plt.subplots()

ax2 = ax.twinx()
ax.plot(l_cont, f_cont, color = 'b', label = 'science')
ax.plot(l_cont, s_cont, color = 'r', label = 'sky residuals')
#ax.plot(wavelength, flux, label = "OG redshifted flux")

ax2.plot(l_cont, thpt_cont, color = 'g', label = 'throughput')
ax2.plot(l_cont, atm_cont, color = 'purple', label = 'atmosphere')

ax.set_xlabel('Wavelength (micron)')
ax.set_ylabel('Photons/Pixel/sec')
ax2.set_ylabel('Transmission')


lines1, labels1 = ax.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax2.legend(lines1 + lines2, labels1 + labels2)

fig.suptitle("")

plt.tight_layout()
plt.show()

#SNR time!

rn = 21 #electrons per pixel
n_reads = 16
n_spatial = angular_extent/0.38 #property of object --> doesn't change with lambda

exp_time = 1000

eta_read = (rn/np.sqrt(n_reads)) * np.sqrt(n_spatial) # read noise
eta_dark = np.sqrt(n_spatial * 0.005 * exp_time) # dark current

eta_tot = []
for i in range(len(dispersions)):
    val1 = [f*exp_time for f in flux_photons_per_pixel[i]]
    val2 = [s**2 for s in sky_photons_per_pixel[i]]
    val = (val2) + (val2 * exp_time) + (eta_dark)**2 + (eta_read)**2
    val = np.sqrt(val)
    eta_tot.append(val)

snr = []
snr_cont = []
for i in range(len(dispersions)):
    val = [f*exp_time/n for f, n in zip(flux_photons_per_pixel[i], eta_tot[i])]
    snr.append(val)

    snr_cont.extend(snr[i])

plt.plot(l_cont, snr_cont)
plt.show()