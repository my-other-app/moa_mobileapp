import 'package:flutter/material.dart';

import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// The app's own drawing of a certificate, from the template's flat style
/// fields (colours, title, logo) -- the ones the website's certificate page
/// draws from too.
///
/// It is a stand-in, not the certificate: a design made in the clubs
/// dashboard's layer designer keeps everything in its layers, which this
/// cannot draw, so for those it comes out as the same default card for
/// every club. The certificate screen shows the server's render of the
/// club's design (CertificateRender) and falls back to this, marked as a
/// preview, only when no render can be had.
class CertificatePreview extends StatelessWidget {
  final Certificate certificate;
  final CertificateStyle style;

  /// Who it is made out to. Null while the profile is still loading, which
  /// leaves the name line blank rather than printing "null".
  final String? recipientName;

  const CertificatePreview({
    super.key,
    required this.certificate,
    required this.style,
    this.recipientName,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // A4 landscape, matching what the PDF generator produces, so the
      // preview is the shape of the thing being downloaded.
      aspectRatio: style.landscape ? 1.414 : 0.707,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Scaled off the width so the certificate keeps its proportions
          // whether it is a list thumbnail or the full detail panel.
          final unit = constraints.maxWidth / 100;

          return Container(
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(unit * 1.5),
              border: Border.all(color: style.border, width: unit * 0.4),
              image: style.backgroundImageUrl == null
                  ? null
                  : DecorationImage(
                      image: appImageProvider(
                        style.backgroundImageUrl!,
                        decodeWidth: (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(1, maxDecodePixels),
                      ),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: unit * 7,
              vertical: unit * 6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  style.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.accent,
                    fontSize: unit * 5.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: unit * 0.2,
                  ),
                ),
                SizedBox(height: unit * 3),
                Container(
                  width: unit * 18,
                  height: unit * 0.5,
                  color: style.accent,
                ),
                SizedBox(height: unit * 4),
                Text(
                  'This is to certify that',
                  style: TextStyle(
                    color: style.secondaryText,
                    fontSize: unit * 3,
                  ),
                ),
                SizedBox(height: unit * 2),
                Text(
                  recipientName ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.text,
                    fontSize: unit * 6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: unit * 2),
                Text(
                  'attended',
                  style: TextStyle(
                    color: style.secondaryText,
                    fontSize: unit * 3,
                  ),
                ),
                SizedBox(height: unit * 1.5),
                Flexible(
                  child: Text(
                    certificate.eventName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.text,
                      fontSize: unit * 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        certificate.clubName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: style.secondaryText,
                          fontSize: unit * 2.6,
                        ),
                      ),
                    ),
                    if (style.showCertificateId)
                      Flexible(
                        child: Text(
                          certificate.ticketId,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: style.secondaryText,
                            fontSize: unit * 2.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
