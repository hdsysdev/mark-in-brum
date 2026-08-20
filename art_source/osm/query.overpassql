[out:json][timeout:180];
(
  way["building"](52.4700,-1.9160,52.4850,-1.8900);
  way["highway"~"^(primary|secondary|tertiary|residential|pedestrian|footway|living_street|service)$"](52.4700,-1.9160,52.4850,-1.8900);
  way["amenity"](52.4700,-1.9160,52.4850,-1.8900);
  way["landuse"~"^(grass|recreation_ground)$"](52.4700,-1.9160,52.4850,-1.8900);
  way["barrier"](52.4700,-1.9160,52.4850,-1.8900);
  way["natural"="water"](52.4700,-1.9160,52.4850,-1.8900);
);
out body;
>;
out skel qt;
