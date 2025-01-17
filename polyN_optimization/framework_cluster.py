import subprocess
import os
import glob
import sys
import multiprocessing
import pandas as pd
import time
import numpy as np
import time
from scipy.interpolate import interp1d
from scipy.integrate import simps
from optimize_polyN_cluster import first_opti, write_coeff_abq, get_param_polyN
from optimize_polyN_mini_cluster import first_opti_mini, write_coeff_abq_mini, get_param_polyN_mini
from get_calibration_data import analyze_exp_data

sep = os.sep
polyN_cali_dir = os.path.dirname(os.path.abspath(__file__))
exec_dir = polyN_cali_dir + sep + "running"


from data_visualizing.compare_sim_exp import compare_large_strain
from read_param import read_param
from running.run_large_sim_cluster import launch_run, create_csv

p = read_param()
func = p["func"]
material = p["material"]
law = p["law"]
degree = int(p["degree"])
protomodel = p["protomodel"]
input_type = p["input_type"]
n_opti = int(p["n_opti"])
density = p["density"]
var_optim = p["var_optim"].split(",")
var_optim = np.array([int(var_optim[i]) for i in range(len(var_optim))])
enu = p["enu"]
results_sim_dir = polyN_cali_dir + sep + "results_sim" + sep + material

mat_exp = analyze_exp_data(material)
tests = []
for type_test in mat_exp.keys():
    for ori in mat_exp[type_test]:
        if type_test != "UT":
            test = type_test + "_" + ori
            tests.append(test)

def numerical_gradient(f, x, n_try):
    h = 0.5
    grad = np.zeros_like(x)
    for i in range(x.size):

        print(n_try)
        temp_val = x[i]
        x[i] = temp_val + h
        fxh1 = f(x, 2 * n_try)
        
        x[i] = temp_val - h 
        fxh2 = f(x, 2 * n_try + 1)  
        
        grad[i] = (fxh1 - fxh2) / (2 * h)
        x[i] = temp_val  
        
    return grad

def gradient_descent(f, x0, learning_rate=0.1, n_opti=n_opti):
    x = x0
    for i in range(n_opti):
        grad = numerical_gradient(f, x, i)
        print("grad, lr", grad, learning_rate)
        x = x - learning_rate * grad
    return x

def mean_square_error(test, var_optim=0, n_try=0):
    results_sim_dir = polyN_cali_dir + sep + "results_sim" + sep + material
    sim_res_path = results_sim_dir + sep + test + "_" + input_type + "_" + str(var_optim) + "_" + str(n_try) + ".csv"
    df_sim = pd.read_csv(sim_res_path)
    x_sim = df_sim["U2"]
    y_sim = df_sim["RF2"]
    f_sim = interp1d(x_sim, y_sim, kind="linear", fill_value="extrapolate")

    results_exp_dir = polyN_cali_dir + sep + "results_exp" + sep + material
    type_test, ori = test.split("_")
    n_exp = mat_exp[type_test][ori]
    dfs = []
    lens = []
    disps = np.empty(0)
    forces = np.empty(0)

    for m in range(1):
        exp_res_path = results_exp_dir + sep + type_test + "_" + ori + f"_{m+1}.csv"
        df_exp = pd.read_csv(exp_res_path)
        e = df_exp["Displacement longi[mm]"] if type_test == "SH" else df_exp["Displacement[mm]"]
        s = df_exp["Force[kN]"]
        lens.append(len(e))
        disps = np.concatenate((disps, e))
        forces = np.concatenate((forces, s))
    
    f_exp = interp1d(disps, forces, kind="linear", fill_value="extrapolate")
    x_common = np.linspace(0, min(max(x_sim), max(e)), num=500)
    y1_common = f_sim(x_common)
    y2_common = f_exp(x_common)
    y1_common[0] = 0
    y2_common[0] = 0
    y_diff = np.abs(y1_common - y2_common)
    area_between_curves = simps(y=y_diff, x=x_common)
    print(test, y1_common, y2_common, x_common, var_optim, n_try)
    return(area_between_curves)

def framework_param_study(lb, ub, step):
    """
        Generate large tests plots (force according to displacement) for different 
        coeffs of polyN. We are testing for values centered around the one first
        found by the optimization algorithm. Basically the var_optim variable moves
        in [initial_guess + lb, initial_guess + ub] with a step.
        Input :
            - lb : integer (negative)
            - ub : integer (positive)
            - step : integer
            - var_optim : integer (refer to constraint.txt to choose)
    """
    t0 = time.time()
    coeff_polyN = first_opti()
    powers = get_param_polyN(degree)
    nmon = len(powers)
    coeff_law = np.load(polyN_cali_dir + sep + f"{law}_coeff.npy")
    
    a = coeff_law[0]
    b = coeff_law[1]
    c = coeff_law[2]
    ymod = coeff_law[3]

    for i_var in range(14, nmon):
        dcoeffs = np.zeros((n_opti, nmon))
        dcoeffs[:,i_var] = np.arange(lb, ub, step)
        n_dcoeff = len(dcoeffs)
        for i in range(n_dcoeff) :
            new_coeff = coeff_polyN + dcoeffs[i]
            print(new_coeff)
            write_coeff_abq(new_coeff, a, b, c, ymod, enu, nmon, protomodel, degree, material, law, density, powers, i_var + 1, i)
            launch_run(tests, material, degree, law, protomodel, input_type, i_var + 1, i)
    
            time.sleep(90)

            create_csv(tests, material, input_type, i_var + 1, i)
            compare_large_strain(material, degree, input_type, i_var + 1, i)

def framework(var_optim):
    """
        TODO, CHANGE RUN AND CREATE CSV
    """
    t0 = time.time()
    coeff_polyN = first_opti()
    
    coeff_law = np.load(polyN_cali_dir + sep + f"{law}_coeff.npy")
    a = coeff_law[0]
    b = coeff_law[1]
    c = coeff_law[2]
    ymod = coeff_law[3]

    def f_cost(x, n_try):
        powers = get_param_polyN(degree)
        nmon = len(powers)

        new_coeff = np.copy(coeff_polyN)
        new_coeff[var_optim - 1] = new_coeff[var_optim - 1] + x

        write_coeff_abq(new_coeff, a, b, c, ymod, enu, nmon, protomodel, degree, material, law, density, powers, n_try=n_try)
        launch_run(tests, material, degree, law, protomodel, input_type, n_try=n_try)
        time.sleep(300)
        create_csv(tests, material, input_type, n_try=n_try)
        compare_large_strain(material, degree, input_type, n_try=n_try)

        err = 0

        for test in tests:
            err = err + mean_square_error(test, n_try=n_try)
            print("err:", err)
        
        return(err)
    

    x0 = np.zeros(len(var_optim))
    result = gradient_descent(f_cost, x0)

    coeff_polyN[var_optim] = coeff_polyN[var_optim] + result
    coeff_file = polyN_cali_dir + sep + "polyN_coeff.npy"
    np.save(coeff_polyN, coeff_file)
    print(coeff_polyN)

def framework_mini(var_optim):
    """
        TODO, CHANGE RUN AND CREATE CSV
    """
    t0 = time.time()

    coeff_file = polyN_cali_dir + sep + material + "_polyN_mini_coeff.npy"
    
    if os.path.exists(coeff_file):
        coeff_polyN_mini = np.load(coeff_file)
    else :
        coeff_polyN_mini = first_opti_mini()

    coeff_law = np.load(polyN_cali_dir + sep + f"{material}_{law}_mini_coeff.npy")
    a = coeff_law[0]
    b = coeff_law[1]
    c = coeff_law[2]
    ymod = coeff_law[3]

    def f_cost(x, n_try):

        powers = get_param_polyN_mini(degree)
        nmon = len(powers)

        new_coeff = np.copy(coeff_polyN_mini)
        new_coeff[var_optim - 1] = new_coeff[var_optim - 1] + x

        write_coeff_abq_mini(new_coeff, a, b, c, ymod, enu, nmon, protomodel, degree, material, law, density, powers, n_try=n_try)
        launch_run(tests, func, material, degree, law, protomodel, input_type, n_try=n_try)
        time.sleep(300)
        create_csv(tests, material, input_type, n_try=n_try)
        compare_large_strain(material, func, degree, input_type, n_try=n_try)

        err = 0

        for test in tests:
            err = err + mean_square_error(test, n_try=n_try)
            print("err:", err)
        
        return(err)
    
    x0 = np.zeros(len(var_optim))
    result = gradient_descent(f_cost, x0)

    coeff_polyN_mini[var_optim] = coeff_polyN_mini[var_optim] + result
    coeff_file = polyN_cali_dir + sep + "polyN_mini_coeff_final.npy"
    np.save(coeff_polyN_mini, coeff_file)
    print(coeff_polyN_mini)


if __name__ == "__main__":
    if func == "polyN":
        framework(var_optim)
    elif func == "polyN_mini":
        framework_mini(var_optim)