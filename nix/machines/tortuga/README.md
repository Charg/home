# `tortuga` install (dual boot with Windows)

This machine uses:
- One disk shared with Windows; NixOS gets the second half
- Its own 1 GiB ESP (`nixos-esp`) — Windows' ESP is left untouched
- LUKS root (`nixos-root` → `cryptroot`), ext4
- NVIDIA proprietary driver (open kernel modules)
- User `chris`, configured from the `nix/users/framework` profile

## On-demand GPU node (k3s agent)

`k3s.nix` joins tortuga to the nuc01 cluster as a k3s **agent** that is *not*
started at boot. It exposes the RTX 4080 SUPER as `nvidia.com/gpu` (via
`kube/nuc01/nvidia-device-plugin`) and is tainted `nvidia.com/gpu=true:NoSchedule`,
so only GPU workloads land here.

```zsh
gpu-node on      # start k3s, wait for Ready, uncordon
gpu-node off     # drain, stop k3s and kill its containers (frees the VRAM)
gpu-node status
```

While off, GPU pods sit `Pending` and the node shows `NotReady`; they are
rescheduled on the next `gpu-node on`.

### Smoke test

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: Never
  runtimeClassName: nvidia
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: cuda
      image: nvidia/cuda:12.8.0-base-ubuntu24.04
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
```

`kubectl logs gpu-test` should print the 4080 SUPER.

## Game streaming (Helios)

`helios.nix` runs [Helios](https://github.com/moonlight-os/helios), a Sunshine
fork, built with CUDA so it can encode on the 4080 with NVENC. The service runs
Helios inside a headless Sway session rendered on the 4080, and each client
gets its own display there; the GNOME session and the G9 are left untouched.
(Helios can start a private Sway itself, but only after it has already picked
a capture method, so launched from GNOME it finds nothing to capture.)

```zsh
systemctl --user start helios   # not started with the session
```

Then pair a client from the web UI at <https://localhost:47990>. The first
paired client gets admin permissions.

Caveats:
- **Use a controller.** Keyboard and mouse input from a client goes to the
  GNOME session (which isn't visible on the stream), not to the Sway session.
  Controllers work, as games read them directly.
- **Audio:** while streaming, Helios switches the default output to its own
  virtual sink, so the speakers go quiet until the session ends.
- **Steam is single-instance:** if Steam is already open on the GNOME desktop,
  launching it from Helios opens games there instead. Quit it first.
- **Login:** Helios is a user service, so after a Wake-on-LAN boot it isn't
  running until someone logs in at GDM.
