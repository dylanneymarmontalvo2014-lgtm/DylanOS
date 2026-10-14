// DYLANOS-MOCK: Simulated disk data.
// DYLANOS-INTEGRATION: Replace with real data from Calamares partition module.

export interface Partition {
  device: string;
  type: string;
  mount: string;
  fs: string;
  size: string;
  sizeGB: number;
  used: string;
  color: string;
}

export interface Disk {
  device: string;
  size: string;
  sizeGB: number;
  model: string;
  partitions: Partition[];
}

export const mockDisks: Disk[] = [
  {
    device: "/dev/sda",
    size: "512 GB",
    sizeGB: 512,
    model: "KINGSTON SA400S37/512G",
    partitions: [
      { device: "/dev/sda1", type: "Primaria", mount: "/", fs: "ext4", size: "200 GB", sizeGB: 200, used: "32 GB", color: "#dc2626" },
      { device: "/dev/sda2", type: "Primaria", mount: "swap", fs: "swap", size: "8 GB", sizeGB: 8, used: "0 B", color: "#d97706" },
      { device: "/dev/sda3", type: "Primaria", mount: "/home", fs: "ext4", size: "100 GB", sizeGB: 100, used: "12 GB", color: "#3b82f6" },
      { device: "Espacio libre", type: "—", mount: "—", fs: "—", size: "204 GB", sizeGB: 204, used: "—", color: "#374151" },
    ],
  },
];
