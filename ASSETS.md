# Asset provenance

`Resources/AppIconSource.png` is project-original artwork generated specifically
for NatureRemoMac and selected as the canonical editable source. It does not
contain a Nature Inc. logo or an asset copied from an official Nature app.

`Resources/AppIcon.icns` is generated from that source with
`script/generate_app_icon.sh`. Both files are distributed under the repository's
MIT License.

Alternative drafts and generated intermediate iconsets are intentionally not
tracked. Regenerate the `.icns` file after changing the canonical source instead
of committing temporary iconset files.
