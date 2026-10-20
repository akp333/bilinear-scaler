# Parameterized Fixed-Point Bilinear Image Scaler (Verilog RTL)

A pipelined, integer-only bilinear image scaler written in Verilog HDL.
The module reads a pre-stored 8-bit grayscale image from a hex file, resizes it to a
parameterized output resolution using bilinear interpolation, and writes the result
back out as a hex file. No floating point is used anywhere.

Built for I-Chip '26 PS-1 (SCALE-X), Udyam '26, Electronics Engineering Society.

## Features

- Parameterized input and output resolution (`W_in`, `H_in`, `W_out`, `H_out`)
- Fixed-point (Q8.8) source-coordinate computation, integer arithmetic only
- Fully pipelined datapath, one output pixel issued per clock
- Edge clamping, so the 2x2 neighbourhood never reads outside the image
- Rounded (not truncated) interpolation result
- File-based I/O with `$readmemh` / `$writememh` 

## How it works

### 1. Coordinate mapping

For every output pixel `(x_out, y_out)` the source coordinate is

```
x_in = x_out * (W_in / W_out)
y_in = y_out * (H_in / H_out)
```

The ratio is precomputed once at compile time as a rounded Q8.8 constant, so there
is no divider in hardware:

```verilog
localparam [15:0] scale_x = (W_in*256 + W_out/2) / W_out;
localparam [15:0] scale_y = (H_in*256 + H_out/2) / H_out;
```

`x_in = scale_x * x_out` is then a single multiply. The upper bits are the integer
pixel `x0` and the low 8 bits are the fraction `a` (0 to 255, meaning a/256).

### 2. Neighbour selection and clamping

```
x0 = min(x_in >> 8, W_in - 1)        x1 = min(x0 + 1, W_in - 1)
y0 = min(y_in >> 8, H_in - 1)        y1 = min(y0 + 1, H_in - 1)
```

The four neighbours are `I00 = I(x0,y0)`, `I10 = I(x1,y0)`, `I01 = I(x0,y1)`,
`I11 = I(x1,y1)`.

### 3. Interpolation

With `a`, `b` as 8-bit fractions (units of 1/256):

```
val = (256-a)(256-b)*I00 + a(256-b)*I10 + (256-a)b*I01 + ab*I11
out = (val + 32768) >> 16
```

The four weights sum to 256 x 256 = 2^16, so adding half (32768) and shifting right
by 16 divides by 2^16 with round-to-nearest. The largest possible `val` is
255 x 65536, so the result always fits in 8 bits and needs no saturation logic.

## Architecture

| Stage | Registers | What happens |
|-------|-----------|--------------|
| Control | `cnt_x`, `cnt_y`, `running`, `issued_last` | Raster scan over output coordinates, one pixel per clock |
| S1 | `s1_*` | Q8.8 source coordinates `x_in`, `y_in` |
| S2 | `s2_*` | Integer neighbours `x0`, `y0`, `x1`, `y1` (clamped) |
| S3 | `s3_*` | Fractions `a`, `b`, neighbour indices |
| S4 | `s4_*` | Fetch of the four neighbour pixels from `input_img` |
| Final | `output_img` | Weighted sum, rounding, write at `y_out*W_out + x_out` |

Each stage carries `x_out`, `y_out` and a `valid` bit alongside its data, so the
final stage knows where to write. Latency is 5 clocks from issue to write.
`done` goes high when the last output pixel has been written, and the output file is
dumped while `done` is high.

## Interface

| Port | Dir | Description |
|------|-----|-------------|
| `clk` | in | Clock |
| `rst` | in | Asynchronous reset, active high |
| `start` | in | Starts a scaling run when the module is idle |
| `done` | out | High when the output image is complete |

| Parameter | Default | Description |
|-----------|---------|-------------|
| `W_in` | 4 | Input width (must match `input.hex`) |
| `H_in` | 4 | Input height (must match `input.hex`) |
| `W_out` | 6 | Output width |
| `H_out` | 10 | Output height |

## File formats

- **`input.hex`**: one 8-bit pixel per line in hex, row-major order,
  `W_in * H_in` lines.
- **`output.hex`**: same format, `W_out * H_out` lines.

## Status and limitations

- Grayscale (1 channel) only at the moment; RGB support is not implemented yet.
- The scale factor is a rounded Q8.8 constant, so the sampling position can drift
  slightly for large output sizes.
- Interpolation weights are 8-bit fractions, and their products are 16 bits wide
  internally before the final round-and-shift.
- `$readmemh` / `$writememh` are for simulation only, as allowed by the PS.
- The final pixel is pushed through the pipeline a few extra times after it is
  issued; it rewrites the same value to the same address, so the output is unaffected.
