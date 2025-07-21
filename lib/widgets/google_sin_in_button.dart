import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleSignInButton extends StatefulWidget {
  final Future<void> Function()? onSignIn;
  const GoogleSignInButton({Key? key, this.onSignIn}) : super(key: key);

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.onSignIn?.call();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      onPressed: _isLoading ? null : _handleSignIn,
      child: _isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/google_logo.svg',
                  height: 22,
                  width: 22,
                ),
                const SizedBox(width: 12),
                const Text('Sign in with Google'),
              ],
            ),
    );
  }
}
