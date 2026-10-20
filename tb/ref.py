import numpy as np
from skimage.metrics import structural_similarity as ssim

W_in, H_in, W_out, H_out = 474, 296, 500, 500

def read_hex(path, h, w):
    vals = []
    for line in open(path):
        line = line.split("//")[0].strip()
        if line and not line.startswith("@"):
            vals += [int(t, 16) for t in line.split()]
    assert len(vals) == h * w, f"{path}: expected {h*w} values, found {len(vals)}"
    return np.array(vals, dtype=np.uint8).reshape(h, w)

def ref_resize(img, Wo, Ho):
    Hi, Wi = img.shape
    xi = np.arange(Wo) * Wi / Wo
    yi = np.arange(Ho) * Hi / Ho
    x0 = np.minimum(xi.astype(int), Wi - 1);  x1 = np.minimum(x0 + 1, Wi - 1)
    y0 = np.minimum(yi.astype(int), Hi - 1);  y1 = np.minimum(y0 + 1, Hi - 1)
    a = (xi - x0)[None, :];  b = (yi - y0)[:, None]
    out = ((1-a)*(1-b)*img[np.ix_(y0, x0)] + a*(1-b)*img[np.ix_(y0, x1)] + (1-a)*b*img[np.ix_(y1, x0)] + a*b*img[np.ix_(y1, x1)])
    return np.rint(out).clip(0, 255).astype(np.uint8)

src = read_hex("input.hex",  H_in,  W_in)
hw  = read_hex("output.hex", H_out, W_out)
ref = ref_resize(src, W_out, H_out)

diff = np.abs(hw.astype(int) - ref.astype(int))
mse  = np.mean(diff.astype(float) ** 2)
psnr = float("inf") if mse == 0 else 10 * np.log10(255 ** 2 / mse)
win  = min(7, H_out, W_out); win -= (win % 2 == 0)

print(f"PSNR = {psnr:.2f} dB")
print(f"SSIM = {ssim(ref, hw, data_range=255, win_size=win):.4f}")
print(f"max pixel difference = {diff.max()}")
