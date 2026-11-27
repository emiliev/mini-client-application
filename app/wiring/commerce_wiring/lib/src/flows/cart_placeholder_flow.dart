import 'package:flutter/material.dart';

/// Stands in for the cart feature's flow at `/store/cart`, so a route builds a
/// `*Flow` as R15 asks (as publishing_wiring's creator placeholder does).
/// Replaced by the cart feature (F078) later.
class CartPlaceholderFlow extends StatelessWidget {
  const CartPlaceholderFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('cart.placeholder'),
      appBar: AppBar(title: const Text('Cart')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your cart', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text('The cart arrives with its feature.', style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}
