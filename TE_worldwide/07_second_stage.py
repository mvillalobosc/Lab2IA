"""Second stage: contextual variables and the published IO-CRS score (Table 2, Supplementary Tables S9, S14, S15).

Usage:  python 07_second_stage.py full        eight predictors: VIF, Tobit (bootstrap 500), OLS-HC1, Simar-Wilson 1 and 2
        python 07_second_stage.py reduced     main model (GNI per capita dropped): same estimators
        python 07_second_stage.py extra       main model: Tobit without Singapore (bootstrap 500) and year-specific Tobit (200)
        python 07_second_stage.py assemble    merges the three JSON files into results/second_stage_results.json
The three estimation blocks are independent and can run in parallel (about 20 min each on one core). Each block draws its
random numbers from its own generator seeded with config.SEED, in the order written here; keep that order to reproduce
the published bootstrap intervals to the last digit.

Estimators
  Tobit: two-sided censoring at 0 and 1, maximum likelihood; case-resampling bootstrap; percentile 95% intervals; p from the
         normal approximation to the bootstrap standard error.
  OLS:   heteroskedasticity-robust (HC1) standard errors.
  Simar-Wilson Algorithm 1: truncated regression (right truncation at 1) on the observations below the frontier, with the
         parametric bootstrap of Simar and Wilson (2007), L = 2000.
  Simar-Wilson Algorithm 2: annual IO-CRS frontiers re-estimated on the country-years with complete covariates (fresh
         extraction), bias-corrected with L1 = 100 bootstrap frontiers; truncated regression on the bias-corrected scores
         with L2 = 1000 parametric bootstrap replications.
"""
import json, sys, time
import numpy as np, pandas as pd
from scipy.stats import norm
from dea_lib import dea_input, fit_tobit, fit_truncreg, draw_truncated
from config import DATA, RESULTS, YEARS, INPUTS, OUTPUTS, SEED, PRED_FULL, PRED_MAIN, add_rescaled

block = sys.argv[1] if len(sys.argv) > 1 else "assemble"
df = add_rescaled(pd.read_csv(DATA / "fresh_annual_scores.csv"))
cc = df.dropna(subset=PRED_FULL + ["te_io_crs"]).copy()          # 445 country-years with every covariate observed
assert len(cc) == 445, len(cc)
B, BY, L_SW1, L1, L2 = 500, 200, 2000, 100, 1000


def tobit_boot(rng, d, pred, B):
    y = d.te_io_crs.values; Z = np.column_stack([np.ones(len(d)), d[pred].values])
    th = fit_tobit(y, Z)
    boot = np.zeros((B, len(th)))
    for b in range(B):
        idx = rng.integers(0, len(y), len(y))
        boot[b] = fit_tobit(y[idx], Z[idx], x0=th)
    se = boot.std(axis=0, ddof=1); p = 2 * norm.sf(np.abs(th / se)); ci = np.percentile(boot, [2.5, 97.5], axis=0)
    names = ["Intercept"] + pred + ["log sigma"]
    return {n: dict(coef=float(th[i]), se=float(se[i]), p=float(p[i]), ci_lo=float(ci[0, i]), ci_hi=float(ci[1, i])) for i, n in enumerate(names)}


def ols_hc1(d, pred):
    y = d.te_io_crs.values; Z = np.column_stack([np.ones(len(d)), d[pred].values])
    b, *_ = np.linalg.lstsq(Z, y, rcond=None); e = y - Z @ b; n, k = Z.shape
    XtX_inv = np.linalg.inv(Z.T @ Z); V = XtX_inv @ ((Z * (e[:, None] ** 2)).T @ Z) @ XtX_inv * n / (n - k); se = np.sqrt(np.diag(V))
    return {nm: dict(coef=float(b[i]), se=float(se[i]), p=float(2 * norm.sf(abs(b[i] / se[i]))), ci_lo=float(b[i] - 1.96 * se[i]), ci_hi=float(b[i] + 1.96 * se[i]))
            for i, nm in enumerate(["Intercept"] + pred)}


def sw1(rng, d, pred, L):
    y = d.te_io_crs.values; Z = np.column_stack([np.ones(len(d)), d[pred].values])
    m = y < 1; y1, Z1 = y[m], Z[m]
    tr = fit_truncreg(y1, Z1); beta, sig = tr[:-1], np.exp(tr[-1])
    bt = np.zeros((L, len(tr)))
    for l in range(L):
        eps = draw_truncated(np.zeros(len(y1)), sig, hi=1 - Z1 @ beta, rng=rng)
        bt[l] = fit_truncreg(Z1 @ beta + eps, Z1, x0=tr)
    ci = np.percentile(bt, [2.5, 97.5], axis=0)
    out = {n: dict(coef=float(tr[i]), ci_lo=float(ci[0, i]), ci_hi=float(ci[1, i]), sig=bool(ci[0, i] > 0 or ci[1, i] < 0)) for i, n in enumerate(["Intercept"] + pred + ["log sigma"])}
    return out, int(m.sum())


def sw2(rng, pred, L1, L2, tag):
    rows = []
    for yr in YEARS:
        d = df[df.year == yr].dropna(subset=pred).copy()
        X = d[INPUTS].values; Y = d[OUTPUTS].values
        th = dea_input(X, Y, "crs")
        Zy = np.column_stack([np.ones(len(d)), d[pred].values])
        m = th < 1
        trp = fit_truncreg(th[m], Zy[m]); b_y, s_y = trp[:-1], np.exp(trp[-1])
        boots = np.zeros((L1, len(d)))
        for l in range(L1):
            eps = draw_truncated(np.zeros(len(d)), s_y, hi=1 - Zy @ b_y, rng=rng)
            th_star = np.clip(Zy @ b_y + eps, 1e-3, 1.0)
            boots[l] = dea_input(X, Y, "crs", refX=X * (th / th_star)[:, None], refY=Y)
        bias = boots.mean(axis=0) - th
        d["th_fresh"] = th; d["bias"] = bias; d["th_bc"] = th - bias
        rows.append(d)
        print(f"  SW2 {yr}: mean fresh={th.mean():.3f} bias-corrected={(th - bias).mean():.3f}", flush=True)
    bc = pd.concat(rows)
    ybc = bc.th_bc.values; Zbc = np.column_stack([np.ones(len(bc)), bc[pred].values]); mb = ybc < 1
    tr2 = fit_truncreg(ybc[mb], Zbc[mb]); beta2, sig2 = tr2[:-1], np.exp(tr2[-1])
    bt2 = np.zeros((L2, len(tr2)))
    for l in range(L2):
        eps = draw_truncated(np.zeros(mb.sum()), sig2, hi=1 - Zbc[mb] @ beta2, rng=rng)
        bt2[l] = fit_truncreg(Zbc[mb] @ beta2 + eps, Zbc[mb], x0=tr2)
    ci2 = np.percentile(bt2, [2.5, 97.5], axis=0)
    out = {n: dict(coef=float(tr2[i]), ci_lo=float(ci2[0, i]), ci_hi=float(ci2[1, i]), sig=bool(ci2[0, i] > 0 or ci2[1, i] < 0)) for i, n in enumerate(["Intercept"] + pred + ["log sigma"])}
    bc[["code", "year", "th_fresh", "th_bc", "bias"]].to_csv(RESULTS / f"bias_corrected_scores_{tag}.csv", index=False)
    by_year = {int(yr): dict(mean_fresh=round(float(x.th_fresh.mean()), 3), mean_bc=round(float(x.th_bc.mean()), 3), mean_bias=round(float(x.bias.mean()), 3)) for yr, x in bc.groupby("year")}
    return out, int(mb.sum()), by_year


def vif_table(d, pred):
    vif = {}
    for p in pred:
        others = [q for q in pred if q != p]
        A = np.column_stack([np.ones(len(d)), d[others].values])
        b, *_ = np.linalg.lstsq(A, d[p].values, rcond=None)
        r2 = 1 - (d[p].values - A @ b).var() / d[p].values.var()
        vif[p] = round(float(1 / (1 - r2)), 2)
    return vif


def print_block(name, res, pred):
    print(name)
    for n in ["Intercept"] + pred:
        r = res[n]; extra = f" se={r['se']:.5f} p={r['p']:.4f}" if "se" in r else ""
        print(f"  {n:10s} coef={r['coef']: .5f}{extra} ci=({r['ci_lo']: .5f},{r['ci_hi']: .5f})")


def estimation_block(pred, tag):
    rng = np.random.default_rng(SEED)
    R = {"n": int(len(cc)), "n_at_1": int((cc.te_io_crs >= 1).sum()), "pred": pred,
         "vif": vif_table(cc, pred), "corr": cc[pred + ["pop_m"]].corr().round(2).to_dict()}
    print(tag, "VIF:", R["vif"])
    t0 = time.time()
    R["tobit"] = tobit_boot(rng, cc, pred, B); print_block(f"Tobit {tag} (%.0fs)" % (time.time() - t0), R["tobit"], pred)
    R["ols"] = ols_hc1(cc, pred); print_block(f"OLS-HC1 {tag}", R["ols"], pred)
    json.dump(R, open(RESULTS / f"second_stage_{tag}.json", "w"), indent=1)
    R["sw1"], R["sw1_n"] = sw1(rng, cc, pred, L_SW1); print_block(f"Simar-Wilson 1 {tag} (%.0fs)" % (time.time() - t0), R["sw1"], pred)
    json.dump(R, open(RESULTS / f"second_stage_{tag}.json", "w"), indent=1)
    R["sw2"], R["sw2_n"], R["sw2_by_year"] = sw2(rng, pred, L1, L2, tag); print_block(f"Simar-Wilson 2 {tag} (%.0fs)" % (time.time() - t0), R["sw2"], pred)
    json.dump(R, open(RESULTS / f"second_stage_{tag}.json", "w"), indent=1)
    print("saved results/second_stage_%s.json" % tag)


if block == "full":
    estimation_block(PRED_FULL, "full")
elif block == "reduced":
    estimation_block(PRED_MAIN, "reduced")
elif block == "extra":
    rng = np.random.default_rng(SEED)
    R = {}
    t0 = time.time()
    R["tobit_main_check"] = tobit_boot(rng, cc, PRED_MAIN, B)          # same draws as the 'reduced' block: identical to its Tobit
    print("main Tobit re-run done %.0fs" % (time.time() - t0), flush=True)
    R["tobit_noSGP"] = tobit_boot(rng, cc[cc.code != "SGP"], PRED_MAIN, B); R["n_noSGP"] = int((cc.code != "SGP").sum())
    print_block("Tobit without Singapore (%.0fs)" % (time.time() - t0), R["tobit_noSGP"], PRED_MAIN)
    ys = {}
    for yr in YEARS:
        d = cc[cc.year == yr]
        r = tobit_boot(rng, d, PRED_MAIN, BY)
        ys[int(yr)] = dict(n=int(len(d)), n_at_1=int((d.te_io_crs >= 1).sum()), **{p: r[p] for p in PRED_MAIN})
        print(" ", yr, "n=", len(d), {p: ("+" if r[p]["coef"] > 0 else "-") for p in PRED_MAIN if r[p]["p"] < 0.05}, flush=True)
    R["tobit_by_year"] = ys
    json.dump(R, open(RESULTS / "second_stage_extra.json", "w"), indent=1)
    print("saved results/second_stage_extra.json")
elif block == "assemble":
    F = json.load(open(RESULTS / "second_stage_full.json")); M = json.load(open(RESULTS / "second_stage_reduced.json")); E = json.load(open(RESULTS / "second_stage_extra.json"))
    for k in ["Intercept"] + PRED_MAIN:      # the 'extra' block must reproduce the main Tobit exactly
        assert abs(E["tobit_main_check"][k]["coef"] - M["tobit"][k]["coef"]) < 1e-9 and abs(E["tobit_main_check"][k]["se"] - M["tobit"][k]["se"]) < 1e-9, k
    R = {"n": M["n"], "n_at_1": M["n_at_1"], "n_noSGP": E["n_noSGP"], "sw1_n": M["sw1_n"], "sw2_n": M["sw2_n"],
         "vif_full": F["vif"], "vif_reduced": M["vif"], "corr": F["corr"],
         "tobit_full": F["tobit"], "sw1_full": F["sw1"], "sw2_full": F["sw2"],
         "tobit_reduced": M["tobit"], "ols_reduced": M["ols"], "sw1_reduced": M["sw1"], "sw2_reduced": M["sw2"], "sw2_by_year": M["sw2_by_year"],
         "tobit_reduced_noSGP": E["tobit_noSGP"], "tobit_by_year_reduced": E["tobit_by_year"]}
    json.dump(R, open(RESULTS / "second_stage_results.json", "w"), indent=1)
    print("saved results/second_stage_results.json")
else:
    raise SystemExit("block must be full | reduced | extra | assemble")
