# Parameterized Fixed-Point Bilinear Image Scaler (Verilog RTL)

A pipelined, integer-only bilinear image scaler written in Verilog HDL.
The module reads a pre-stored 8-bit grayscale image from a hex file, resizes it to a
parameterized output resolution using bilinear interpolation, and writes the result
back out as a hex file. No floating point is used anywhere in the design.

Built for I-Chip '26 PS-1 (SCALE-X), Udyam '26, Electronics Engineering Society.

## Features

- Parameterized input and output resolution (`W_in`, `H_in`, `W_out`, `H_out`)
- Fixed-point source-coordinate computation with 8 fractional bits, integer arithmetic only
- No divider in hardware (the scale ratio is a compile-time constant)
- Fully pipelined datapath, one output pixel issued per clock, with no idle or delay stage
- Edge clamping, so the 2x2 neighbourhood never reads outside the image
- Rounded (not truncated) interpolation result
- File-based I/O with `$readmemh` / `$writememh`

## How it works

### 1. Coordinate mapping

Fixed-point: Use whole-number arithmetic and treat the lowest 8 bits as the
digits after the decimal point.

For every output pixel $(x_{out}, y_{out})$ the matching position in the input image is

$$x_{in} = x_{out} \times \frac{W_{in}}{W_{out}}, \qquad y_{in} = y_{out} \times \frac{H_{in}}{H_{out}}$$

The ratio is computed once at compile time as a rounded fixed-point constant, so there
is no divider in hardware:

```verilog
localparam [15:0] scale_x = (W_in*256 + W_out/2) / W_out;
localparam [15:0] scale_y = (H_in*256 + H_out/2) / H_out;
```

This is $\text{round}(W_{in} \cdot 256 / W_{out})$, i.e. the ratio in units of 1/256.
Then $x_{in}$ is a single multiplication, `scale_x * x_out`. The upper bits (`>> 8`) are
the whole-pixel position $x_0$, and the lowest 8 bits are the fraction $a$ (a number from
0 to 255, meaning $a/256$). The same applies to $y_{in}$, $y_0$ and $b$.

### 2. Neighbour selection and clamping

Clamping: Limiting an index to the last valid pixel so it never points outside the image.

$$x_0 = \min\left(\lfloor x_{in} \rfloor,\ W_{in}-1\right), \qquad x_1 = \min(x_0 + 1,\ W_{in}-1)$$

$$y_0 = \min\left(\lfloor y_{in} \rfloor,\ H_{in}-1\right), \qquad y_1 = \min(y_0 + 1,\ H_{in}-1)$$

The four neighbours are `I00 = I(x0,y0)`, `I10 = I(x1,y0)`, `I01 = I(x0,y1)` and
`I11 = I(x1,y1)`.

### 3. Interpolation

With $a$ and $b$ as 8-bit fractions (units of 1/256):

$$\text{val} = (256-a)(256-b)\,I_{00} + a(256-b)\,I_{10} + (256-a)\,b\,I_{01} + a\,b\,I_{11}$$

$$\text{out} = \frac{\text{val} + 32768}{65536} \quad (\text{done as a right shift by 16})$$

The four weights always add up to $256 \times 256 = 2^{16}$, so dividing by $2^{16}$ is just a
right shift by 16 bits. Adding half of $2^{16}$ (that is 32768) first makes the result
round to the nearest whole number instead of being cut off. The largest possible `val` is
$255 \times 65536$, so the result always fits in 8 bits and no saturation logic is needed.

### 4. Number sizes (precision)

The only fractional precision used is 8 bits (`a` and `b`, 0 to 255). Everything else is
plain integer arithmetic carried at full width and rounded down to 8 bits once, at the end.

| Value | Largest value | Bits needed |
|-------|---------------|-------------|
| `a`, `b` (fractions) | 255 | 8 |
| `256-a`, `256-b` (complementary weights) | 256 | 9 |
| Weight product, e.g. `(256-a)(256-b)` | 65536 | 17 |
| `val` (weighted sum) | 255 x 65536 | 24 |
| Output pixel (after round and shift) | 255 | 8 |

## Architecture

The design is a 4-stage pipeline. Once the pipeline is full, one output pixel is
finished every clock cycle. There is no idle or pass-through stage: every stage does
real work.

| Stage | Registers | What happens |
|-------|-----------|--------------|
| Control | `cnt_x`, `cnt_y`, `running`, `issued_last` | Counts through the output pixels row by row (left to right, top to bottom), one pixel per clock |
| S1 | `s1_*` | Fixed-point source coordinates `x_in`, `y_in` |
| S2 | `s2_*` | Whole-pixel neighbours `x0`, `y0`, `x1`, `y1` (clamped) and fractions `a`, `b` |
| S3 | `s3_*` | Fetch of the four neighbour pixels from `input_img`; fractions `a`, `b` carried along |
| Final | `output_img` | Weighted sum, rounding, write at `y_out*W_out + x_out` |

Each stage carries `x_out`, `y_out` and a `valid` bit alongside its data. The `valid` bit
says whether the data is a real pixel, and the coordinates tell the final stage where to
write. Latency is 4 clocks from issue to write. `done` goes high when the last output
pixel has been written, and the output file is dumped on every clock while `done` is high.

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

- **`input.hex`**: one 8-bit pixel per line in hex, row by row, `W_in * H_in` lines.
- **`output.hex`**: same format, `W_out * H_out` lines.

## Results

Test: grayscale image, 474 x 296 scaled up to 500 x 500.

The output was compared pixel by pixel against a floating-point reference of the
PS equations (`x_in = x_out * W_in / W_out`, same edge clamping, rounded to the
nearest integer), computed in Python from the same `input.hex`. The Python model is
used only to measure accuracy after simulation. It is not part of the design, and the
Verilog uses integer arithmetic only.

| Metric | Result |
|--------|--------|
| PSNR | 28.25 dB |
| SSIM | 0.8743 |
| Max pixel difference | 118 (out of 255) |

The error is a slight shift of the sampling points, not noise. It comes from the
rounded scale factors, which for this size are `scale_x = 243` (exact value
242.69) and `scale_y = 152` (exact value 151.55). That small error is multiplied
by the output pixel position, so the sampling point drifts.

## Status and limitations

- Grayscale (1 channel) only at the moment; RGB support is not implemented yet.
- The scale factor is a rounded constant, so the sampling position drifts
  for large output sizes (measured 28.25 dB PSNR on 474 x 296 to 500 x 500, see
  Results). Using an exact step and remainder instead of a rounded constant would
  remove most of this drift.
- `$readmemh` / `$writememh` are for simulation only, as allowed by the PS.
- `$writememh` runs on every clock while `done` is high, not once. The file written is
  still correct, but it is repeated work in simulation.
- The final pixel is pushed through the pipeline a few extra times after it is
  issued; it rewrites the same value to the same address, so the output is unaffected.
- Synthesis and static timing analysis have not been done.
