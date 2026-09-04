//! Window previews for the switcher: a captured frame shrunk to a small RGB image.

use std::io::{self, BufWriter, Write};
use std::path::Path;

pub struct Rgb {
    pub width: u32,
    pub height: u32,
    pub pixels: Vec<u8>,
}

/// Byte order of a 32-bit pixel in memory; the fourth byte is alpha or padding either way.
#[derive(Clone, Copy)]
pub enum Order {
    Bgrx,
    Rgbx,
}

/// Box-filters a 32-bit frame down by an integer factor so the result is at most `max_width`
/// wide; rows and columns that don't fill a whole box are dropped.
pub fn shrink(frame: &[u8], width: u32, height: u32, stride: u32, order: Order, max_width: u32) -> Rgb {
    let factor = width.div_ceil(max_width).max(1);
    let (tw, th) = ((width / factor).max(1), (height / factor).max(1));
    let count = factor * factor;
    let (ri, bi) = match order {
        Order::Bgrx => (2, 0),
        Order::Rgbx => (0, 2),
    };
    let mut pixels = Vec::with_capacity((tw * th * 3) as usize);
    for ty in 0..th {
        for tx in 0..tw {
            let (mut r, mut g, mut b) = (0u32, 0u32, 0u32);
            for y in ty * factor..(ty + 1) * factor {
                let row = (y * stride) as usize;
                for x in tx * factor..(tx + 1) * factor {
                    let px = row + (x * 4) as usize;
                    r += frame[px + ri] as u32;
                    g += frame[px + 1] as u32;
                    b += frame[px + bi] as u32;
                }
            }
            pixels.extend([(r / count) as u8, (g / count) as u8, (b / count) as u8]);
        }
    }
    Rgb { width: tw, height: th, pixels }
}

/// Binary PPM: Qt reads it without any image plugin. Written beside the target and renamed
/// so a reader never sees a partial file.
pub fn write_ppm(image: &Rgb, path: &Path) -> io::Result<()> {
    let tmp = path.with_extension("tmp");
    let mut file = BufWriter::new(std::fs::File::create(&tmp)?);
    write!(file, "P6\n{} {}\n255\n", image.width, image.height)?;
    file.write_all(&image.pixels)?;
    file.flush()?;
    std::fs::rename(tmp, path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shrinks_by_averaging_boxes() {
        // 4x2 XRGB frame, stride 16: left half red, right half blue.
        let mut frame = Vec::new();
        for _ in 0..2 {
            frame.extend([0, 0, 255, 0, 0, 0, 255, 0, 255, 0, 0, 0, 255, 0, 0, 0]);
        }
        let image = shrink(&frame, 4, 2, 16, Order::Bgrx, 2);
        assert_eq!((image.width, image.height), (2, 1));
        assert_eq!(image.pixels, vec![255, 0, 0, 0, 0, 255]);
    }

    #[test]
    fn keeps_small_frames() {
        let frame = vec![10, 20, 30, 0];
        let image = shrink(&frame, 1, 1, 4, Order::Rgbx, 320);
        assert_eq!((image.width, image.height), (1, 1));
        assert_eq!(image.pixels, vec![10, 20, 30]);
    }
}
