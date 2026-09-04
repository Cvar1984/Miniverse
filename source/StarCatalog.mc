// Bright naked-eye star catalog: J2000 RA/Dec (degrees) and visual magnitude.
// Proper motion and precession are ignored; the error is far below what a
// wrist compass/magnetometer can resolve.
module StarCatalog {
    function getStars() {
        return [
            {:name => "Sirius", :ra => 101.287, :dec => -16.716, :mag => -1.46},
            {:name => "Canopus", :ra => 95.988, :dec => -52.696, :mag => -0.74},
            {:name => "Alpha Centauri", :ra => 219.900, :dec => -60.834, :mag => -0.27},
            {:name => "Arcturus", :ra => 213.916, :dec => 19.182, :mag => -0.05},
            {:name => "Vega", :ra => 279.234, :dec => 38.784, :mag => 0.03},
            {:name => "Capella", :ra => 79.172, :dec => 45.998, :mag => 0.08},
            {:name => "Rigel", :ra => 78.634, :dec => -8.202, :mag => 0.13},
            {:name => "Procyon", :ra => 114.825, :dec => 5.225, :mag => 0.34},
            {:name => "Betelgeuse", :ra => 88.793, :dec => 7.407, :mag => 0.50},
            {:name => "Achernar", :ra => 24.429, :dec => -57.237, :mag => 0.46},
            {:name => "Hadar", :ra => 210.956, :dec => -60.373, :mag => 0.61},
            {:name => "Altair", :ra => 297.696, :dec => 8.868, :mag => 0.76},
            {:name => "Aldebaran", :ra => 68.980, :dec => 16.509, :mag => 0.85},
            {:name => "Antares", :ra => 247.352, :dec => -26.432, :mag => 0.96},
            {:name => "Spica", :ra => 201.298, :dec => -11.161, :mag => 1.04},
            {:name => "Pollux", :ra => 116.329, :dec => 28.026, :mag => 1.14},
            {:name => "Fomalhaut", :ra => 344.413, :dec => -29.622, :mag => 1.16},
            {:name => "Deneb", :ra => 310.358, :dec => 45.280, :mag => 1.25},
            {:name => "Regulus", :ra => 152.093, :dec => 11.967, :mag => 1.36},
            {:name => "Castor", :ra => 113.650, :dec => 31.888, :mag => 1.58},
            {:name => "Bellatrix", :ra => 81.283, :dec => 6.350, :mag => 1.64},
            {:name => "Alnilam", :ra => 84.053, :dec => -1.202, :mag => 1.69},
            {:name => "Alnitak", :ra => 85.190, :dec => -1.943, :mag => 1.77},
            {:name => "Alkaid", :ra => 206.885, :dec => 49.313, :mag => 1.86},
            {:name => "Polaris", :ra => 37.955, :dec => 89.264, :mag => 1.98},
            {:name => "Alphard", :ra => 141.897, :dec => -8.659, :mag => 1.98},
            {:name => "Mizar", :ra => 200.981, :dec => 54.925, :mag => 2.23},
            {:name => "Denebola", :ra => 177.265, :dec => 14.572, :mag => 2.14}
        ];
    }
}
