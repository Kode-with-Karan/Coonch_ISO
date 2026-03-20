# Custom R8 rules for Stripe optional Push Provisioning classes
# These classes are referenced by flutter_stripe but shipped only when the
# optional push provisioning dependency is present. Suppress warnings so R8
# can complete without the optional module.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
