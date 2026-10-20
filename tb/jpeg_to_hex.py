from PIL import Image

img = Image.open("photo.jpg").convert("L")
img.save("input.png")

with open("input.hex", "w") as f:
    for p in img.getdata():
        f.write(f"{p:02x}\n")
