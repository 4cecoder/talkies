# Windows motion and reduced motion

Talkies uses short ease-out transitions for newly appearing transcript segments,
the hotkey status overlay, and the recording control that becomes available after
a state change. These transitions are deliberately small and do not delay input.

The app follows Windows' **Animate controls and elements inside windows** client
area animation setting (`SystemParameters.ClientAreaAnimation`). When Windows
disables that setting, transcript and overlay content appears immediately and
recording controls do not scale. Window sizing remains under the native window
manager so resizing stays responsive.

The duration policy is covered by `UiMotionTests`. Visual behavior still needs
manual validation on Windows with client area animations both enabled and
disabled.
