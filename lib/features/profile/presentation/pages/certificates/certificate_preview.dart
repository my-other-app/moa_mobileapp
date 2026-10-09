import 'package:flutter/material.dart';

import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';

/// A rendering of the certificate itself, styled by the club's template.
///
/// The detail screen used to show the event's poster here, falling back to
/// an icon when there was none -- which is most events, so the panel showed
/// a logo and nothing of the certificate.
///
/// There is no image to fetch: certificates are generated as PDFs on
/// request and nothing stores a picture of one. So the preview is drawn
/// from the same style config the event website renders from.
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
                      image: NetworkImage(style.backgroundImageUrl!),
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
