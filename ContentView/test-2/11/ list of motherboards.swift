// In SSDTGeneratorView, update the motherboardModels array:

let motherboardModels = [
    // Gigabyte
    "Gigabyte Z390 AORUS PRO",
    "Gigabyte Z390 AORUS ELITE",
    "Gigabyte Z390 AORUS MASTER",
    "Gigabyte Z390 DESIGNARE",
    "Gigabyte Z390 UD",
    "Gigabyte Z390 GAMING X",
    "Gigabyte Z390 M GAMING",
    "Gigabyte Z390 AORUS PRO WIFI",
    "Gigabyte Z390 AORUS ULTRA",
    "Gigabyte Z390 GAMING SLI",
    "Gigabyte Z390 AORUS XTREME",
    
    "Gigabyte Z490 AORUS PRO AX",
    "Gigabyte Z490 VISION G",
    "Gigabyte Z490 AORUS ELITE AC",
    "Gigabyte Z490 UD AC",
    "Gigabyte Z490 AORUS MASTER",
    "Gigabyte Z490I AORUS ULTRA",
    "Gigabyte Z490 AORUS XTREME",
    
    "Gigabyte Z590 AORUS PRO AX",
    "Gigabyte Z590 VISION G",
    "Gigabyte Z590 AORUS ELITE AX",
    "Gigabyte Z590 UD AC",
    "Gigabyte Z590 AORUS MASTER",
    
    "Gigabyte Z690 AORUS PRO",
    "Gigabyte Z690 AORUS ELITE AX",
    "Gigabyte Z690 GAMING X",
    "Gigabyte Z690 UD AX",
    "Gigabyte Z690 AERO G",
    "Gigabyte Z690 GAMING X DDR4",
    
    "Gigabyte Z790 AORUS ELITE AX",
    "Gigabyte Z790 GAMING X AX",
    "Gigabyte Z790 UD AC",
    "Gigabyte Z790 AORUS MASTER",
    
    "Gigabyte B360M DS3H",
    "Gigabyte B365M DS3H",
    "Gigabyte B460M DS3H",
    "Gigabyte B560M DS3H",
    "Gigabyte B660M DS3H AX",
    "Gigabyte B760M DS3H AX",
    
    "Gigabyte H310M S2H",
    "Gigabyte H370M DS3H",
    "Gigabyte H410M S2H",
    "Gigabyte H510M S2H",
    "Gigabyte H610M S2H",
    
    // ASUS
    "ASUS PRIME Z390-A",
    "ASUS PRIME Z390-P",
    "ASUS ROG STRIX Z390-E GAMING",
    "ASUS ROG STRIX Z390-F GAMING",
    "ASUS ROG STRIX Z390-H GAMING",
    "ASUS ROG STRIX Z390-I GAMING",
    "ASUS ROG MAXIMUS XI HERO",
    "ASUS ROG MAXIMUS XI CODE",
    "ASUS ROG MAXIMUS XI FORMULA",
    "ASUS TUF Z390-PLUS GAMING",
    
    "ASUS PRIME Z490-A",
    "ASUS ROG STRIX Z490-E GAMING",
    "ASUS ROG STRIX Z490-F GAMING",
    "ASUS ROG STRIX Z490-H GAMING",
    "ASUS ROG STRIX Z490-I GAMING",
    "ASUS TUF GAMING Z490-PLUS",
    
    "ASUS PRIME Z590-A",
    "ASUS ROG STRIX Z590-E GAMING",
    "ASUS ROG STRIX Z590-F GAMING",
    "ASUS ROG STRIX Z590-I GAMING",
    "ASUS TUF GAMING Z590-PLUS",
    
    "ASUS PRIME Z690-A",
    "ASUS ROG STRIX Z690-A GAMING WIFI D4",
    "ASUS ROG STRIX Z690-F GAMING WIFI",
    "ASUS ROG STRIX Z690-G GAMING WIFI",
    "ASUS ROG STRIX Z690-I GAMING WIFI",
    "ASUS TUF GAMING Z690-PLUS WIFI D4",
    
    "ASUS PRIME B360M-A",
    "ASUS PRIME B365M-A",
    "ASUS PRIME B460M-A",
    "ASUS PRIME B560M-A",
    "ASUS PRIME B660M-A WIFI D4",
    "ASUS PRIME B760M-A WIFI D4",
    
    "ASUS PRIME H310M-A",
    "ASUS PRIME H370-A",
    "ASUS PRIME H410M-A",
    "ASUS PRIME H510M-A",
    "ASUS PRIME H610M-A WIFI D4",
    
    // MSI
    "MSI MPG Z390 GAMING PRO CARBON",
    "MSI MPG Z390 GAMING EDGE AC",
    "MSI MPG Z390 GAMING PLUS",
    "MSI MAG Z390 TOMAHAWK",
    "MSI MAG Z390M MORTAR",
    "MSI MEG Z390 ACE",
    "MSI MEG Z390 GODLIKE",
    
    "MSI MPG Z490 GAMING PLUS",
    "MSI MPG Z490 GAMING EDGE WIFI",
    "MSI MPG Z490 GAMING CARBON WIFI",
    "MSI MAG Z490 TOMAHAWK",
    "MSI MEG Z490 ACE",
    "MSI MEG Z490 GODLIKE",
    
    "MSI MPG Z590 GAMING PLUS",
    "MSI MPG Z590 GAMING EDGE WIFI",
    "MSI MAG Z590 TOMAHAWK WIFI",
    "MSI MEG Z590 ACE",
    
    "MSI PRO Z690-A WIFI",
    "MSI MPG Z690 EDGE WIFI",
    "MSI MAG Z690 TOMAHAWK WIFI",
    "MSI MEG Z690 ACE",
    
    "MSI B360M MORTAR",
    "MSI B365M PRO-VH",
    "MSI B460M PRO-VDH WIFI",
    "MSI B560M PRO-VDH WIFI",
    "MSI PRO B660M-A WIFI DDR4",
    "MSI PRO B760M-A WIFI DDR4",
    
    "MSI H310M PRO-VDH PLUS",
    "MSI H370M BAZOOKA",
    "MSI H410M PRO",
    "MSI H510M PRO",
    "MSI PRO H610M-B DDR4",
    
    // ASRock
    "ASRock Z390 Phantom Gaming 4",
    "ASRock Z390 Phantom Gaming 4S",
    "ASRock Z390 Phantom Gaming SLI",
    "ASRock Z390 Pro4",
    "ASRock Z390 Steel Legend",
    "ASRock Z390 Taichi",
    
    "ASRock Z490 Phantom Gaming 4",
    "ASRock Z490 Steel Legend",
    "ASRock Z490 Taichi",
    "ASRock Z490 Extreme4",
    
    "ASRock Z590 Phantom Gaming 4",
    "ASRock Z590 Steel Legend",
    "ASRock Z590 Extreme",
    "ASRock Z590 Taichi",
    
    "ASRock Z690 Phantom Gaming 4",
    "ASRock Z690 Steel Legend",
    "ASRock Z690 Extreme",
    "ASRock Z690 Taichi",
    
    "ASRock B360M Pro4",
    "ASRock B365M Pro4",
    "ASRock B460M Pro4",
    "ASRock B560M Pro4",
    "ASRock B660M Pro RS",
    "ASRock B760M Pro RS",
    
    "ASRock H310M-HDV",
    "ASRock H370M Pro4",
    "ASRock H410M-HDV",
    "ASRock H510M-HDV",
    "ASRock H610M-HDV",
    
    // Dell
    "Dell OptiPlex 7010",
    "Dell OptiPlex 7020",
    "Dell OptiPlex 7050",
    "Dell OptiPlex 7060",
    "Dell OptiPlex 7070",
    "Dell OptiPlex 7080",
    "Dell OptiPlex 7090",
    
    "Dell Precision T3610",
    "Dell Precision T5810",
    "Dell Precision T7810",
    "Dell Precision T7910",
    
    "Dell XPS 8930",
    "Dell XPS 8940",
    
    // HP
    "HP EliteDesk 800 G1",
    "HP EliteDesk 800 G2",
    "HP EliteDesk 800 G3",
    "HP EliteDesk 800 G4",
    "HP EliteDesk 800 G5",
    "HP EliteDesk 800 G6",
    
    "HP ProDesk 600 G1",
    "HP ProDesk 600 G2",
    "HP ProDesk 600 G3",
    "HP ProDesk 600 G4",
    "HP ProDesk 600 G5",
    
    "HP Z240",
    "HP Z440",
    "HP Z640",
    "HP Z840",
    
    // Lenovo
    "Lenovo ThinkCentre M93p",
    "Lenovo ThinkCentre M73",
    "Lenovo ThinkCentre M83",
    "Lenovo ThinkCentre M900",
    "Lenovo ThinkCentre M910",
    "Lenovo ThinkCentre M920",
    "Lenovo ThinkCentre M920q",
    
    "Lenovo ThinkStation P320",
    "Lenovo ThinkStation P330",
    "Lenovo ThinkStation P520",
    "Lenovo ThinkStation P920",
    
    // Intel NUC
    "Intel NUC8i7BEH",
    "Intel NUC8i5BEH",
    "Intel NUC8i3BEH",
    
    "Intel NUC10i7FNH",
    "Intel NUC10i5FNH",
    "Intel NUC10i3FNH",
    
    "Intel NUC11PAHi7",
    "Intel NUC11PAHi5",
    "Intel NUC11PAHi3",
    
    // Other popular Hackintosh boards
    "Supermicro X11SSM-F",
    "Supermicro X11SSL-F",
    "Supermicro X11SAE-F",
    
    "ASUS PRIME X299-A",
    "ASUS ROG STRIX X299-E GAMING",
    
    "Gigabyte X299 DESIGNARE EX",
    "Gigabyte X299 UD4 PRO",
    
    // Laptops
    "Dell XPS 13 9360",
    "Dell XPS 13 9370",
    "Dell XPS 13 9380",
    "Dell XPS 15 9560",
    "Dell XPS 15 9570",
    "Dell XPS 15 9500",
    
    "Lenovo ThinkPad T480",
    "Lenovo ThinkPad T480s",
    "Lenovo ThinkPad T490",
    "Lenovo ThinkPad X1 Carbon 6th Gen",
    "Lenovo ThinkPad X1 Carbon 7th Gen",
    
    "HP EliteBook 840 G5",
    "HP EliteBook 840 G6",
    "HP EliteBook 850 G5",
    "HP EliteBook 850 G6",
    
    "Acer Swift 3",
    "Acer Aspire 5",
    "Asus ZenBook UX430",
    "Asus ZenBook UX533",
    
    // Custom/Other
    "Custom Build",
    "Other/Unknown Motherboard",
    "Generic Desktop PC",
    "All-in-One PC",
    "Mini PC"
]

// Also update the gpuModels array:

let gpuModels = [
    // AMD Radeon
    "AMD Radeon RX 560",
    "AMD Radeon RX 570",
    "AMD Radeon RX 580",
    "AMD Radeon RX 590",
    "AMD Radeon RX 5500 XT",
    "AMD Radeon RX 5600 XT",
    "AMD Radeon RX 5700",
    "AMD Radeon RX 5700 XT",
    "AMD Radeon RX 6600 XT",
    "AMD Radeon RX 6700 XT",
    "AMD Radeon RX 6800",
    "AMD Radeon RX 6800 XT",
    "AMD Radeon RX 6900 XT",
    "AMD Radeon RX 6950 XT",
    "AMD Radeon RX 7900 XT",
    "AMD Radeon RX 7900 XTX",
    
    // AMD Radeon Vega
    "AMD Radeon RX Vega 56",
    "AMD Radeon RX Vega 64",
    "AMD Radeon Vega Frontier Edition",
    
    // AMD Radeon Pro
    "AMD Radeon Pro W5700",
    "AMD Radeon Pro W6800",
    "AMD Radeon Pro W6900X",
    "AMD Radeon Pro W7800",
    "AMD Radeon Pro W7900",
    
    // NVIDIA GeForce 10 Series
    "NVIDIA GeForce GTX 1050",
    "NVIDIA GeForce GTX 1050 Ti",
    "NVIDIA GeForce GTX 1060 3GB",
    "NVIDIA GeForce GTX 1060 6GB",
    "NVIDIA GeForce GTX 1070",
    "NVIDIA GeForce GTX 1070 Ti",
    "NVIDIA GeForce GTX 1080",
    "NVIDIA GeForce GTX 1080 Ti",
    
    // NVIDIA GeForce 16 Series
    "NVIDIA GeForce GTX 1650",
    "NVIDIA GeForce GTX 1650 Super",
    "NVIDIA GeForce GTX 1660",
    "NVIDIA GeForce GTX 1660 Super",
    "NVIDIA GeForce GTX 1660 Ti",
    
    // NVIDIA GeForce 20 Series
    "NVIDIA GeForce RTX 2060",
    "NVIDIA GeForce RTX 2060 Super",
    "NVIDIA GeForce RTX 2070",
    "NVIDIA GeForce RTX 2070 Super",
    "NVIDIA GeForce RTX 2080",
    "NVIDIA GeForce RTX 2080 Super",
    "NVIDIA GeForce RTX 2080 Ti",
    
    // NVIDIA GeForce 30 Series (Limited support with OCLP)
    "NVIDIA GeForce RTX 3050",
    "NVIDIA GeForce RTX 3060",
    "NVIDIA GeForce RTX 3060 Ti",
    "NVIDIA GeForce RTX 3070",
    "NVIDIA GeForce RTX 3070 Ti",
    "NVIDIA GeForce RTX 3080",
    "NVIDIA GeForce RTX 3080 Ti",
    "NVIDIA GeForce RTX 3090",
    "NVIDIA GeForce RTX 3090 Ti",
    
    // NVIDIA GeForce 40 Series (Limited/No support)
    "NVIDIA GeForce RTX 4060",
    "NVIDIA GeForce RTX 4060 Ti",
    "NVIDIA GeForce RTX 4070",
    "NVIDIA GeForce RTX 4070 Ti",
    "NVIDIA GeForce RTX 4080",
    "NVIDIA GeForce RTX 4090",
    
    // NVIDIA Quadro/Tesla
    "NVIDIA Quadro P400",
    "NVIDIA Quadro P600",
    "NVIDIA Quadro P1000",
    "NVIDIA Quadro P2000",
    "NVIDIA Quadro P4000",
    "NVIDIA Quadro P5000",
    "NVIDIA Quadro P6000",
    "NVIDIA Quadro RTX 4000",
    "NVIDIA Quadro RTX 5000",
    "NVIDIA Quadro RTX 6000",
    "NVIDIA Quadro RTX 8000",
    "NVIDIA Tesla P4",
    "NVIDIA Tesla P40",
    
    // Intel Integrated Graphics
    "Intel HD Graphics 4000",
    "Intel HD Graphics 4400",
    "Intel HD Graphics 4600",
    "Intel HD Graphics 5000",
    "Intel HD Graphics 520",
    "Intel HD Graphics 530",
    "Intel HD Graphics 5500",
    "Intel HD Graphics 5600",
    "Intel HD Graphics 6000",
    "Intel HD Graphics 610",
    "Intel HD Graphics 615",
    "Intel HD Graphics 620",
    "Intel HD Graphics 630",
    "Intel HD Graphics 640",
    "Intel HD Graphics 650",
    "Intel UHD Graphics 605",
    "Intel UHD Graphics 610",
    "Intel UHD Graphics 615",
    "Intel UHD Graphics 620",
    "Intel UHD Graphics 630",
    "Intel UHD Graphics 640",
    "Intel UHD Graphics 650",
    "Intel UHD Graphics 730",
    "Intel UHD Graphics 750",
    "Intel UHD Graphics 770",
    
    // Intel Iris Graphics
    "Intel Iris Graphics 5100",
    "Intel Iris Graphics 540",
    "Intel Iris Graphics 550",
    "Intel Iris Graphics 6100",
    "Intel Iris Plus Graphics 640",
    "Intel Iris Plus Graphics 650",
    "Intel Iris Xe Graphics (G7)",
    "Intel Iris Xe Graphics (96EU)",
    "Intel Iris Xe Graphics (80EU)",
    
    // Intel Arc (Limited/No support)
    "Intel Arc A380",
    "Intel Arc A750",
    "Intel Arc A770",
    
    // Older/Other
    "AMD Radeon HD 7750",
    "AMD Radeon HD 7770",
    "AMD Radeon HD 7850",
    "AMD Radeon HD 7870",
    "AMD Radeon R7 250",
    "AMD Radeon R7 260",
    "AMD Radeon R9 270",
    "AMD Radeon R9 280",
    "AMD Radeon R9 280X",
    "AMD Radeon R9 290",
    "AMD Radeon R9 290X",
    "AMD Radeon R9 380",
    "AMD Radeon R9 380X",
    "AMD Radeon R9 390",
    "AMD Radeon R9 390X",
    
    "NVIDIA GeForce GT 710",
    "NVIDIA GeForce GT 730",
    "NVIDIA GeForce GT 740",
    "NVIDIA GeForce GTX 750",
    "NVIDIA GeForce GTX 750 Ti",
    "NVIDIA GeForce GTX 760",
    "NVIDIA GeForce GTX 770",
    "NVIDIA GeForce GTX 780",
    "NVIDIA GeForce GTX 780 Ti",
    "NVIDIA GeForce GTX 950",
    "NVIDIA GeForce GTX 960",
    "NVIDIA GeForce GTX 970",
    "NVIDIA GeForce GTX 980",
    "NVIDIA GeForce GTX 980 Ti",
    
    // Custom/Other
    "Custom/Unknown GPU",
    "Integrated Graphics Only",
    "Dual GPU Setup",
    "Multi-GPU Setup"
]