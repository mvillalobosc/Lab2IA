"""Radial input-oriented DEA (CCR / BCC) with scipy's HiGHS solver, plus second-stage estimators."""
import numpy as np
from scipy.optimize import linprog, minimize
from scipy.stats import norm, truncnorm


def dea_input(X, Y, rts="crs", refX=None, refY=None):
    """Input-oriented radial efficiency of each row of (X, Y) relative to the reference set (refX, refY).
    X: n x m inputs, Y: n x s outputs. Returns theta in (0, 1]."""
    X = np.asarray(X, float); Y = np.asarray(Y, float)
    if refX is None:
        refX, refY = X, Y
    refX = np.asarray(refX, float); refY = np.asarray(refY, float)
    n, m = X.shape
    k = refX.shape[0]
    s = Y.shape[1]
    theta = np.full(n, np.nan)
    for o in range(n):
        # variables: [theta, lambda_1..lambda_k]
        c = np.zeros(1 + k); c[0] = 1.0
        A_ub = np.zeros((m + s, 1 + k)); b_ub = np.zeros(m + s)
        for i in range(m):                      # sum lambda_j x_ji - theta x_oi <= 0
            A_ub[i, 0] = -X[o, i]; A_ub[i, 1:] = refX[:, i]
        for r in range(s):                      # -sum lambda_j y_jr <= -y_or
            A_ub[m + r, 1:] = -refY[:, r]; b_ub[m + r] = -Y[o, r]
        A_eq = b_eq = None
        if rts == "vrs":
            A_eq = np.zeros((1, 1 + k)); A_eq[0, 1:] = 1.0; b_eq = np.array([1.0])
        res = linprog(c, A_ub=A_ub, b_ub=b_ub, A_eq=A_eq, b_eq=b_eq, bounds=[(0, None)] * (1 + k), method="highs")
        if res.status != 0:
            raise RuntimeError(f"LP failed for DMU {o}: {res.message}")
        theta[o] = min(res.x[0], 1.0)
    return theta


# ---------------- Tobit (two-sided censoring at 0 and 1) ----------------
def tobit_loglik(params, y, Z, lo=0.0, hi=1.0):
    beta = params[:-1]; sigma = np.exp(params[-1])
    mu = Z @ beta
    ll = np.zeros_like(y)
    mid = (y > lo) & (y < hi)
    ll[mid] = norm.logpdf((y[mid] - mu[mid]) / sigma) - np.log(sigma)
    ll[y >= hi] = norm.logsf((hi - mu[y >= hi]) / sigma)
    ll[y <= lo] = norm.logcdf((lo - mu[y <= lo]) / sigma)
    return -ll.sum()


def fit_tobit(y, Z, lo=0.0, hi=1.0, x0=None):
    y = np.asarray(y, float); Z = np.asarray(Z, float)
    if x0 is None:
        b0, *_ = np.linalg.lstsq(Z, y, rcond=None)
        s0 = np.log(np.std(y - Z @ b0) + 1e-6)
        x0 = np.concatenate([b0, [s0]])
    res = minimize(tobit_loglik, x0, args=(y, Z, lo, hi), method="BFGS", options={"maxiter": 5000, "gtol": 1e-6})
    if not res.success:
        res = minimize(tobit_loglik, res.x, args=(y, Z, lo, hi), method="Nelder-Mead", options={"maxiter": 20000, "xatol": 1e-8, "fatol": 1e-10})
    return res.x  # beta..., log sigma


# ---------------- Truncated normal regression (right truncation at 1) ----------------
def trunc_loglik(params, y, Z, hi=1.0):
    beta = params[:-1]; sigma = np.exp(params[-1])
    mu = Z @ beta
    z = (y - mu) / sigma
    # density of y given y <= hi: phi(z)/sigma / Phi((hi-mu)/sigma)
    ll = norm.logpdf(z) - np.log(sigma) - norm.logcdf((hi - mu) / sigma)
    return -ll.sum()


def fit_truncreg(y, Z, hi=1.0, x0=None):
    y = np.asarray(y, float); Z = np.asarray(Z, float)
    if x0 is None:
        b0, *_ = np.linalg.lstsq(Z, y, rcond=None)
        s0 = np.log(np.std(y - Z @ b0) + 1e-6)
        x0 = np.concatenate([b0, [s0]])
    res = minimize(trunc_loglik, x0, args=(y, Z, hi), method="BFGS", options={"maxiter": 5000, "gtol": 1e-6})
    if not res.success:
        res = minimize(trunc_loglik, res.x, args=(y, Z, hi), method="Nelder-Mead", options={"maxiter": 20000, "xatol": 1e-8, "fatol": 1e-10})
    return res.x


def draw_truncated(mu, sigma, hi=1.0, rng=None):
    """Draw from N(mu, sigma^2) right-truncated at hi (elementwise)."""
    rng = rng or np.random.default_rng()
    b = (hi - mu) / sigma
    return truncnorm.rvs(-np.inf, b, loc=mu, scale=sigma, random_state=rng)
