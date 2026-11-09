<?php

namespace App\Providers;

use App\Models\PersonalAccessToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Auth::viaRequest('sanctum', function (Request $request) {
            if ($user = Auth::guard('web')->user()) {
                return $user;
            }

            $bearer = $request->bearerToken();
            if (! $bearer) {
                return null;
            }

            $accessToken = PersonalAccessToken::findToken($bearer);
            if (! $accessToken) {
                return null;
            }

            if ($accessToken->expires_at && $accessToken->expires_at->isPast()) {
                return null;
            }

            $accessToken->forceFill(['last_used_at' => now()])->save();

            $user = $accessToken->tokenable;

            return $user?->withAccessToken($accessToken);
        });
    }
}
