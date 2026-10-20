
from PIL import Image
import numpy as np

W_out = 500
H_out = 500

pixels = []

with open("output.hex", "r") as f:
    for line in f:
        line = line.strip()

        if not line or line.startswith("//"):
            continue

        pixels.append(int(line, 16))

expected = W_out * H_out

print("Pixels read:", len(pixels))
print("Pixels expected:", expected)

if len(pixels) != expected:
    raise ValueError(
        f"Expected {expected} pixels, but found {len(pixels)}"
    )

img_array = np.array(pixels, dtype=np.uint8)
img_array = img_array.reshape((H_out, W_out))

img = Image.fromarray(img_array)
img.save("output.png")

print("Image saved as output.png")

img.show()
