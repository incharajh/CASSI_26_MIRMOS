import matplotlib.pyplot as plt
import numpy as np

# ---- for the regular files, not the "no margin" ones -------
# ----- h-codr --------
data_h = np.loadtxt("../throughput/MIRMOS-thpt-h-codr.dat")

lambda_h = data_h[:, 0]
thpt_h = data_h[:, 1]

plt.plot(lambda_h, thpt_h, label = "h band")

# ----- k-codr -----
data_k = np.loadtxt("../throughput/MIRMOS-thpt-k-codr.dat")

lambda_k = data_k[:, 0]
thpt_k = data_k[:, 1]

plt.plot(lambda_k, thpt_k, label = "k band")

# ----- j-codr ------
data_j = np.loadtxt("../throughput/MIRMOS-thpt-j-codr.dat")

lambda_j = data_j[:, 0]
thpt_j = data_j[:, 1]

plt.plot(lambda_j, thpt_j, label = "j band")

# ------- y-codr -------
data_y = np.loadtxt("../throughput/MIRMOS-thpt-y-codr.dat")

lambda_y = data_y[:, 0]
thpt_y = data_y[:, 1]

plt.plot(lambda_y, thpt_y, label = "y band")

plt.xlabel("Wavelength (Angstroms)")
plt.ylabel("Throughput")
plt.title("Lambda vs Throughput")

plt.legend()

plt.show()


# ----- now, for the "no margin" files ------------
data_h_nm = np.loadtxt("../throughput/MIRMOS-thpt-nomargin-h-codr.dat")

lambda_h_nm = data_h_nm[:, 0]
thpt_h_nm = data_h_nm[:, 1]

plt.plot(lambda_h_nm, thpt_h_nm, label = "h band")

# ----- k-codr -----
data_k_nm = np.loadtxt("../throughput/MIRMOS-thpt-nomargin-k-codr.dat")

lambda_k_nm = data_k_nm[:, 0]
thpt_k_nm = data_k_nm[:, 1]

plt.plot(lambda_k_nm, thpt_k_nm, label = "k band")

# ----- j-codr ------
data_j_nm = np.loadtxt("../throughput/MIRMOS-thpt-nomargin-j-codr.dat")

lambda_j_nm = data_j_nm[:, 0]
thpt_j_nm = data_j_nm[:, 1]

plt.plot(lambda_j_nm, thpt_j_nm, label = "j band")

# ------- y-codr -------
data_y_nm = np.loadtxt("../throughput/MIRMOS-thpt-nomargin-y-codr.dat")

lambda_y_nm = data_y_nm[:, 0]
thpt_y_nm = data_y_nm[:, 1]

plt.plot(lambda_y_nm, thpt_y_nm, label = "y band")

plt.xlabel("Wavelength (Angstroms)")
plt.ylabel("Throughput")
plt.title("Lambda vs Throughput (no margin)")

plt.legend()

plt.show()

# ----- this is kinda hard to see the difference between. overlaid plot below: --------------
plt.plot(lambda_h, thpt_h, color = 'b', label = "h band")
plt.plot(lambda_h_nm, thpt_h_nm, '--', color = 'b')

plt.plot(lambda_k, thpt_k, color = 'orange', label = 'k band')
plt.plot(lambda_k_nm, thpt_k_nm, '--', color = 'orange')

plt.plot(lambda_j, thpt_j, color = 'g', label = "j band")
plt.plot(lambda_j_nm, thpt_j_nm, '--', color = 'g')

plt.plot(lambda_y, thpt_y, color = 'r', label = 'y band')
plt.plot(lambda_y_nm, thpt_y_nm, '--', color = 'r')

plt.xlabel("Wavelength (IDK what units)")
plt.ylabel("Throughput")
plt.title("Margin vs No Margin (dashed) Throughput")

plt.legend()
plt.show()
