//
//  MovieDetailView.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import SwiftUI

struct MovieDetailView: View {
    let movie: Movie

    @StateObject private var viewModel = MovieDetailViewModel()

    var body: some View {
        ZStack {
            AppTheme.primaryGradient
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.detailError {
                errorView(error: error)
            } else if let detail = viewModel.movieDetail {
                detailContent(detail: detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.detailError)
        .task(id: movie.pageSlug) {
            await viewModel.loadMovieDetail(slug: movie.pageSlug)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.shimmerGradient)
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)

                LoadingSpinner()
            }

            Text("Loading details...")
                .font(AppFont.bodyMedium)
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private func errorView(error: DetailError) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.errorGlow)
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            VStack(spacing: 8) {
                Text("Something Went Wrong")
                    .font(AppFont.titleMedium)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("Unable to load movie details")
                    .font(AppFont.bodyMedium)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Button {
                Task {
                    await viewModel.loadMovieDetail(slug: movie.pageSlug)
                }
            } label: {
                Text("Try Again")
                    .font(AppFont.labelLarge)
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                    .background(AppTheme.accentGradient)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.accentSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func detailContent(detail: MovieDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                posterImageView(url: detail.posterURL ?? movie.posterURL)

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.title)
                            .font(AppFont.headlineMedium)
                            .foregroundColor(AppTheme.textPrimary)

                        if let subtitle = detail.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(AppFont.bodyMedium)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 16) {
                        if let rating = detail.rating {
                            metadataItem(
                                icon: "star.fill",
                                text: rating
                            )
                        }

                        if let duration = detail.duration {
                            metadataItem(
                                icon: "clock.fill",
                                text: duration
                            )
                        }
                    }

                    if let description = detail.description, !description.isEmpty {
                        descriptionCard(description: description)
                    }
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private func posterImageView(url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholderView(isLoading: true)

            case .success(let image):
                GeometryReader { geometry in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .overlay(gradientOverlay)

            case .failure:
                placeholderView(isLoading: false)

            @unknown default:
                EmptyView()
            }
        }
        .frame(height: 400)
        .clipped()
    }

    private func placeholderView(isLoading: Bool) -> some View {
        ZStack {
            AppTheme.cardGradient

            VStack(spacing: 16) {
                if isLoading {
                    LoadingSpinner()
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppTheme.accentGradient)

                    Text("Image not available")
                        .font(AppFont.caption)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .overlay(gradientOverlay)
        .frame(height: 400)
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.clear,
                AppTheme.surface.opacity(0.3),
                AppTheme.surface
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppFont.labelMedium)
                .foregroundStyle(AppTheme.accentGradient)

            Text(text)
                .font(AppFont.labelLarge)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }

    private func descriptionCard(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(AppFont.titleLarge)
                .foregroundColor(AppTheme.textPrimary)

            Text(description)
                .font(AppFont.bodyLarge)
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: Movie(
                id: "/in/movies/nanu-local/1260141777?search_query=Nenu",
                title: "Nanu Local",
                subtitle: "2017  •  2h 12m  •  Kannada",
                pageSlug: "/in/movies/nanu-local/1260141777?search_query=Nenu",
                posterURL: URL(string: "https://img1.hotstarext.com/image/upload/f_auto,t_web_m_1x/sources/r1/cms/prod/7297/1527297-h-b2349a817a4d")
            )
        )
    }
}
