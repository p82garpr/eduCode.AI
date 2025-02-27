import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/models/activity_model.dart';
import '../../domain/models/submission_model.dart';
import '../../domain/models/enrolled_student_model.dart';

class StatisticsView extends StatelessWidget {
  final List<ActivityModel> activities;
  final List<EnrolledStudent> students;
  final List<Submission> submissions;

  const StatisticsView({
    super.key,
    required this.activities,
    required this.students,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas del curso',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Tarjetas de resumen con animación
          AnimatedSummaryCards(
            activities: activities,
            students: students,
            submissions: submissions,
          ),
          const SizedBox(height: 32),

          // Gráfico de entregas por actividad
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entregas por Actividad',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildSubmissionsChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Gráfico de distribución de notas
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribución de Calificaciones',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildGradesDistributionChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: students.length.toDouble(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= activities.length) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Act ${value.toInt() + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        barGroups: _createBarGroups(),
      ),
      swapAnimationDuration: const Duration(milliseconds: 500),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    return List.generate(activities.length, (index) {
      final submissionsForActivity = submissions
          .where((s) => s.actividadId == activities[index].id)
          .length;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: submissionsForActivity.toDouble(),
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.blue.shade600],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: students.length.toDouble(),
              color: Colors.grey.shade200,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildGradesDistributionChart() {
    final gradeRanges = [0, 2, 4, 6, 8, 10];
    final distribution = List<int>.filled(gradeRanges.length - 1, 0);

    for (var submission in submissions) {
      if (submission.calificacion != null) {
        for (var i = 0; i < gradeRanges.length - 1; i++) {
          if (submission.calificacion! >= gradeRanges[i] && 
              submission.calificacion! <= gradeRanges[i + 1]) {
            distribution[i]++;
            break;
          }
        }
      }
    }

    return LineChart(
      LineChartData(
        minY: -0.2,
        maxY: distribution.reduce((a, b) => a > b ? a : b).toDouble() + 1,
        clipData: FlClipData.all(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()} estudiantes',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= gradeRanges.length - 1) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${gradeRanges[value.toInt()]}-${gradeRanges[value.toInt() + 1]}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const Text('');
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(distribution.length, (index) {
              return FlSpot(index.toDouble(), distribution[index].toDouble());
            }),
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.blue.shade600],
            ),
            barWidth: 4,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: Colors.blue.shade600,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade200.withOpacity(0.3),
                  Colors.blue.shade600.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
}

class AnimatedSummaryCards extends StatefulWidget {
  final List<ActivityModel> activities;
  final List<EnrolledStudent> students;
  final List<Submission> submissions;

  const AnimatedSummaryCards({
    super.key,
    required this.activities,
    required this.students,
    required this.submissions,
  });

  @override
  State<AnimatedSummaryCards> createState() => _AnimatedSummaryCardsState();
}

class _AnimatedSummaryCardsState extends State<AnimatedSummaryCards> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animations = List.generate(5, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            (index + 1) * 0.2,
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSubmissions = widget.submissions.length;
    final totalPossibleSubmissions = widget.activities.length * widget.students.length;
    final gradedSubmissions = widget.submissions.where((s) => s.calificacion != null).length;
    final submissionRate = totalPossibleSubmissions > 0 
        ? (totalSubmissions / totalPossibleSubmissions * 100).toStringAsFixed(1)
        : '0';
    
    final averageGrade = widget.submissions.isEmpty ? 0.0 : 
        widget.submissions.fold<double>(0, (sum, s) => sum + (s.calificacion ?? 0)) / widget.submissions.length;

    final cards = [
      _StatCard(
        title: 'Tasa de entregas',
        value: '$submissionRate%',
        icon: Icons.assignment_turned_in,
        animation: _animations[0],
        color: Colors.blue,
      ),
      _StatCard(
        title: 'Entregas calificadas',
        value: gradedSubmissions.toString(),
        icon: Icons.grading,
        animation: _animations[1],
        color: Colors.green,
      ),
      _StatCard(
        title: 'Nota media',
        value: averageGrade.toStringAsFixed(1),
        icon: Icons.grade,
        animation: _animations[2],
        color: Colors.orange,
      ),
      _StatCard(
        title: 'Total actividades',
        value: widget.activities.length.toString(),
        icon: Icons.assignment,
        animation: _animations[3],
        color: Colors.purple,
      ),
      _StatCard(
        title: 'Estudiantes',
        value: widget.students.length.toString(),
        icon: Icons.people,
        animation: _animations[4],
        color: Colors.teal,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: cards,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Animation<double> animation;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.animation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Opacity(
            opacity: animation.value,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.7),
                      color.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 