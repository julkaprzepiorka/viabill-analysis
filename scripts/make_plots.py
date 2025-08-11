
import argparse
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

def load_csv(path: Path, required_cols=None):
    if not path.exists():
        print(f"[WARN] Missing CSV: {path.name}")
        return None
    df = pd.read_csv(path)
    if required_cols:
        missing = [c for c in required_cols if c not in df.columns]
        if missing:
            print(f"[WARN] {path.name} missing columns: {missing}")
    return df

def parse_month(df, col="month"):
    if df is None or col not in df.columns: 
        return df
    try:
        df[col] = pd.to_datetime(df[col], format="%Y-%m")
    except Exception:
        try:
            df[col] = pd.to_datetime(df[col])
        except Exception:
            pass
    return df

def plot_line(df, x, y, title, outpath: Path):
    if df is None or df.empty: 
        print(f"[SKIP] {title} - empty")
        return
    plt.figure()
    plt.plot(df[x], df[y])
    plt.title(title)
    plt.xlabel(x); plt.ylabel(y)
    if pd.api.types.is_datetime64_any_dtype(df[x]):
        plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(outpath)
    plt.close()
    print(f"[OK] Saved {outpath}")

def plot_bar(df, x, y, title, outpath: Path):
    if df is None or df.empty: 
        print(f"[SKIP] {title} - empty")
        return
    plt.figure()
    plt.bar(df[x], df[y])
    plt.title(title)
    plt.xlabel(x); plt.ylabel(y)
    if pd.api.types.is_datetime64_any_dtype(df[x]):
        plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(outpath)
    plt.close()
    print(f"[OK] Saved {outpath}")

def stacked_bar_from_share(df, index_col, col_col, val_col, title, outpath: Path):
    if df is None or df.empty:
        print(f"[SKIP] {title} - empty")
        return
    wide = df.pivot(index=index_col, columns=col_col, values=val_col).sort_index()
    # plot stacked bars
    plt.figure()
    bottom = None
    for i, c in enumerate(wide.columns):
        if bottom is None:
            plt.bar(wide.index, wide[c])
            bottom = wide[c].values
        else:
            plt.bar(wide.index, wide[c], bottom=bottom)
            bottom = bottom + (wide[c].fillna(0).values)
    plt.title(title)
    plt.xlabel(index_col); plt.ylabel(val_col)
    if pd.api.types.is_datetime64_any_dtype(wide.index):
        plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(outpath)
    plt.close()
    print(f"[OK] Saved {outpath}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default="outputs", help="Directory with CSVs")
    ap.add_argument("--out-dir", default=None, help="Directory for plots (default: <data-dir>/plots)")
    args = ap.parse_args()

    data_dir = Path(args.data_dir)
    out_dir = Path(args.out_dir) if args.out_dir else data_dir / "plots"
    ensure_dir(out_dir)

    # load cvs
    new_cust = parse_month(load_csv(data_dir / "new_customers_by_month.csv", ["month","new_customers"]))
    act_cust = parse_month(load_csv(data_dir / "active_customers_by_month.csv", ["month","active_customers"]))
    vol = parse_month(load_csv(data_dir / "transactions_volume_by_month.csv", ["month","tx_count","tx_amount"]))
    inst = parse_month(load_csv(data_dir / "installments_breakdown_by_month.csv", ["month","installments_count","share_pct"]))
    cat = parse_month(load_csv(data_dir / "merchant_categories_by_month.csv", ["month","category","tx_cnt"]))
    top3 = parse_month(load_csv(data_dir / "merchant_categories_top3_by_month.csv"))
    by_age = load_csv(data_dir / "dpd90_by_age_band.csv", ["age_band","dpd90_rate_pct","tx_cnt"])
    by_income = load_csv(data_dir / "dpd90_by_income_band.csv", ["income_band","dpd90_rate_pct","tx_cnt"])
    by_month = parse_month(load_csv(data_dir / "dpd90_by_tx_month.csv", ["tx_month","dpd90_rate_pct","tx_cnt"]), col="tx_month")
    vint_cum = load_csv(data_dir / "vintage_curves_cumulative.csv", ["cohort_month","month_plus","dpd90_cum_pct"])

    # portfolio overview plots
    if new_cust is not None:
        plot_line(new_cust, "month", "new_customers", "New customers by month", out_dir / "new_customers_by_month.png")
    if act_cust is not None:
        plot_line(act_cust, "month", "active_customers", "Active customers by month", out_dir / "active_customers_by_month.png")
    if vol is not None:
        plot_bar(vol, "month", "tx_count", "Transactions count by month", out_dir / "tx_count_by_month.png")
        plot_line(vol, "month", "tx_amount", "Transactions amount by month", out_dir / "tx_amount_by_month.png")
    if inst is not None:
        stacked_bar_from_share(inst, "month", "installments_count", "share_pct", "Installments share by month", out_dir / "installments_share_by_month.png")

    # payment analysis plots
    if by_age is not None:
        plot_bar(by_age, "age_band", "dpd90_rate_pct", "DPD90 rate by age band", out_dir / "dpd90_by_age_band.png")
    if by_income is not None:
        plot_bar(by_income, "income_band", "dpd90_rate_pct", "DPD90 rate by income band", out_dir / "dpd90_by_income_band.png")
    if by_month is not None:
        plot_line(by_month, "tx_month", "dpd90_rate_pct", "DPD90 rate by transaction month", out_dir / "dpd90_by_tx_month.png")

    # vintage curves (limited number of cohorts)
    if vint_cum is not None and not vint_cum.empty:
        # first 8 cohorts to keep it readable
        cohorts = sorted(vint_cum["cohort_month"].dropna().unique())[:8]
        for coh in cohorts:
            sub = vint_cum[vint_cum["cohort_month"] == coh].sort_values("month_plus")
            plot_line(sub, "month_plus", "dpd90_cum_pct", f"Vintage curve – cohort {coh}", out_dir / f"vintage_curve_{coh}.png")

    print(f"All plots saved to: {out_dir}")

if __name__ == "__main__":
    main()
