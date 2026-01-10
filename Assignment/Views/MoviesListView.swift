//
//  MoviesListView.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import SwiftUI

struct MoviesListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MovieSearchViewModel()
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryGradient
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    smoothLoadingView
                } else if let error = viewModel.searchError {
                    errorView(error: error)
                } else if viewModel.searchText.isEmpty {
                    emptyStateView
                } else if !viewModel.searchResults.isEmpty {
                    movieList
                }
            }
            .navigationTitle("Hotstar Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search for movies..."
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }

    private var smoothLoadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.shimmerGradient)
                    .frame(width: 80,
                           height: 80)
                    .blur(radius: 30)
                
                LoadingSpinner()
            }
            
            Text("Searching...")
                .font(AppFont.bodyMedium)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.iconGlow)
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)

                Image(systemName: "film.stack")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            Text("Search for Movies")
                .font(AppFont.headlineSmall)
                .foregroundColor(AppTheme.textPrimary)

            Text("Start typing to find your favorite movies")
                .font(AppFont.bodyMedium)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .offset(y: -60)
    }

    private func errorView(error: SearchError) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.errorGlow)
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: error == .noResults ? "magnifyingglass" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            Text(error.title)
                .font(AppFont.headlineSmall)
                .foregroundColor(AppTheme.textPrimary)

            Text(error.message)
                .font(AppFont.bodyLarge)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                viewModel.searchText = ""
            }) {
                Text(error.buttonText)
                    .font(AppFont.labelLarge)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.accentGradient)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.accentSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)
        }
        .padding()
        .offset(y: -40)
    }

    private var movieList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.searchResults) { movie in
                    NavigationLink(value: movie) {
                        MovieSearchRowView(movie: movie)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie)
        }
    }
    
    private func logout() {
        print("🚪 User initiated logout")
        
        authManager.logout { [self] in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    authManager.navigateToLogin(from: window)
                }
            }
        }
    }
}

struct MovieSearchRowView: View {
    let movie: Movie

    var body: some View {
        HStack(spacing: 12) {
            posterImage
            
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(AppFont.titleSmall)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)

                Text(movie.subtitle)
                    .font(AppFont.bodyMedium)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var posterImage: some View {
        AsyncImage(url: movie.posterURL) { phase in
            Group {
                switch phase {
                case .empty:
                    posterPlaceholder(isLoading: true)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    posterPlaceholder(isLoading: false)
                @unknown default:
                    posterPlaceholder(isLoading: false)
                }
            }
            .frame(width: 60, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius:8)
                    .stroke(AppTheme.accentGradient, lineWidth: 1)
            )
        }
    }
    
    private func posterPlaceholder(isLoading: Bool) -> some View {
        ZStack {
            AppTheme.cardGradient
            
            if isLoading {
                ProgressView()
                    .tint(AppTheme.accentPrimary)
            } else {
                Image(systemName: "film.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentGradient)
            }
        }
    }
    
    private var defaultIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.cardGradient)
                .frame(width: 60, height: 80)
            
            Image(systemName: "film.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accentGradient)
        }
    }
}

#Preview {
    MoviesListView()
}
